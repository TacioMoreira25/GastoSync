import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/features/settings/domain/models/user_profile.dart';
import 'package:gastosync_app/features/transactions/data/services/cloud_sync_service.dart';
import 'package:gastosync_app/features/transactions/presentation/widgets/manual_transaction_form_modal.dart';
import 'package:gastosync_app/main.dart';

CloudSyncService _createMockSyncService(AppDatabase db) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'synced_transactions': 0,
              'synced_bills': 0,
              'synced_credit_cards': 0,
              'synced_budgets': 0,
              'credit_cards': <Map<String, dynamic>>[],
              'transactions': <Map<String, dynamic>>[],
              'bills': <Map<String, dynamic>>[],
              'budgets': <Map<String, dynamic>>[],
            },
          ),
        );
      },
    ),
  );
  return CloudSyncService(database: db, dio: dio);
}

void main() {
  group('Cartões de Crédito: Sync em Nuvem, CRUD e Visibilidade no Web', () {
    test(
      'CloudSyncService envia cartões pendentes (incluindo soft-delete) mesmo sem transações e hidrata cartões no pull',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());

        const email = 'david@example.com';
        final capturedPushBodies = <Map<String, dynamic>>[];

        final remoteCardsOnServer = <Map<String, dynamic>>[
          {
            'id': 10,
            'client_uuid': '11111111-1111-4111-8111-111111111111',
            'name': 'Cartão Mobile Sync',
            'limit_amount': 3500.0,
            'target_min_percent': 50.0,
            'target_max_percent': 80.0,
            'due_day': 15,
            'is_primary': true,
            'updated_at': '2026-11-16T18:00:00Z',
          },
        ];

        final mockDio = Dio();
        mockDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.contains('/sync/push')) {
                final body = Map<String, dynamic>.from(options.data as Map);
                capturedPushBodies.add(body);
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'synced_transactions': 0,
                      'synced_bills': 0,
                      'synced_credit_cards':
                          (body['credit_cards'] as List).length,
                      'synced_budgets': 0,
                    },
                  ),
                );
                return;
              }
              if (options.path.contains('/sync/pull')) {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'transactions': const [],
                      'bills': const [],
                      'credit_cards': remoteCardsOnServer,
                      'budgets': const [],
                    },
                  ),
                );
                return;
              }
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'Unexpected endpoint',
                ),
              );
            },
          ),
        );

        final syncService = CloudSyncService(database: db, dio: mockDio);

        // 1. Pull inicial (cenário Web vazio recebendo cartão criado no Mobile)
        final imported = await syncService.pullFromCloud(
          jwtToken: 'fake-jwt',
          userEmail: email,
        );
        expect(imported, equals(1));

        var localCards = await db.watchAllCreditCards(userEmail: email).first;
        expect(localCards.length, equals(1));
        expect(localCards.first.name, equals('Cartão Mobile Sync'));
        expect(localCards.first.limitAmount, closeTo(3500.0, 0.01));
        expect(localCards.first.isSynced, isTrue);

        // 2. Cria novo cartão local e executa Push (sem transações/boletos pendentes)
        const localUuid = '22222222-2222-4222-8222-222222222222';
        final createdId = await db.upsertCreditCard(
          clientUuid: localUuid,
          userEmail: email,
          name: 'Cartão Web Novo',
          limitAmount: 5000.0,
          dueDay: 20,
          isPrimary: false,
        );
        expect(createdId, greaterThan(0));

        final pushRes = await syncService.pushPendingTransactions(
          jwtToken: 'fake-jwt',
          userEmail: email,
        );
        expect(pushRes.isCloudSynced, isTrue);
        expect(pushRes.syncedCount, equals(1));
        expect(capturedPushBodies.length, equals(1));

        final pushedCards = capturedPushBodies.first['credit_cards'] as List;
        expect(pushedCards.length, equals(1));
        expect((pushedCards.first as Map)['name'], equals('Cartão Web Novo'));

        final pendingAfterPush =
            await db.getPendingSyncCreditCards(userEmail: email);
        expect(pendingAfterPush, isEmpty);

        // 3. Soft-delete local envia tombstone no push e não é ressuscitado pelo pull
        await db.deleteCreditCard(createdId);
        final tombstonePending =
            await db.getPendingSyncCreditCards(userEmail: email);
        expect(tombstonePending.length, equals(1));
        expect(tombstonePending.first.deletedAt, isNotNull);

        remoteCardsOnServer.add({
          'id': 11,
          'client_uuid': localUuid,
          'name': 'Cartão Web Novo',
          'limit_amount': 5000.0,
          'target_min_percent': 50.0,
          'target_max_percent': 80.0,
          'due_day': 20,
          'is_primary': false,
        });
        await syncService.pullFromCloud(
          jwtToken: 'fake-jwt',
          userEmail: email,
        );

        localCards = await db.watchAllCreditCards(userEmail: email).first;
        expect(localCards.any((c) => c.clientUuid == localUuid), isFalse);

        // 4. Cartão apagado remotamente (ausente em credit_cards do pull) também sai da visão ativa local
        remoteCardsOnServer.clear();
        await syncService.pullFromCloud(
          jwtToken: 'fake-jwt',
          userEmail: email,
        );
        localCards = await db.watchAllCreditCards(userEmail: email).first;
        expect(localCards, isEmpty);
      },
    );

    testWidgets(
      'Dashboard Web exibe Cartões & Limite Saudável (mesmo vazio), Sidebar tem Meus Cartões e navega para subaba Cartões',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockSyncService = _createMockSyncService(db);

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              cloudSyncServiceProvider.overrideWithValue(mockSyncService),
            ],
            child: const GastoSyncApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'marcos.pereira@gastosync.local',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Gasto@2026!',
        );
        await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Dashboard exibe card de Cartões mesmo sem cartões cadastrados ainda
        expect(
          find.byKey(const Key('dashboard_credit_cards_limit_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dashboard_empty_add_card_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('web_sidebar_cards_nav_item')),
          findsNothing,
        );

        // Reserva de Emergência exibe badge de status
        expect(find.text('Reserva de Emergência'), findsOneWidget);
        expect(find.text('Sem cobertura'), findsOneWidget);

        // Tocar em "Cadastrar Cartão" no dashboard Web abre Planejamento direto na subaba de Cartões
        await tester.tap(find.byKey(const Key('dashboard_empty_add_card_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('planning_new_credit_card_button')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'ManualTransactionFormModal permite selecionar e apagar cartão salvo para o userEmail ativo',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockSyncService = _createMockSyncService(db);

        const activeEmail = 'david.web@example.com';

        await db.upsertCreditCard(
          userEmail: activeEmail,
          name: 'Nubank Ultravioleta',
          limitAmount: 4200.0,
          dueDay: 10,
          isPrimary: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              cloudSyncServiceProvider.overrideWithValue(mockSyncService),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (ref.read(userProfileProvider).email != activeEmail) {
                      ref.read(userProfileProvider.notifier).updateProfile(
                            fullName: 'David',
                            email: activeEmail,
                            syncToCloud: false,
                          );
                    }
                  });
                  return const Scaffold(
                    body: ManualTransactionFormModal(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Seleciona pagamento em Crédito para exibir os chips de cartão
        final creditChip = find.byKey(const Key('payment_method_chip_Crédito'));
        await tester.ensureVisible(creditChip);
        await tester.tap(creditChip);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('manual_credit_card_selector_container')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('credit_card_chip_Nubank Ultravioleta')),
          findsOneWidget,
        );

        // Toca no ícone de apagar cartão dentro do chip
        final deleteTooltip = find.byTooltip('Apagar cartão');
        await tester.ensureVisible(deleteTooltip);
        await tester.tap(deleteTooltip);
        await tester.pumpAndSettle();

        final remainingCards =
            await db.watchAllCreditCards(userEmail: activeEmail).first;
        expect(remainingCards, isEmpty);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Remoção de rótulos técnicos (Web/Mobile), Burn Rate sem Monitoramento Diário/amarelo e filtro de Mês/Dia em Transações',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());
        final mockSyncService = _createMockSyncService(db);

        const email = 'marcos.pereira@gastosync.local';
        await db.into(db.localTransactions).insert(
              LocalTransactionsCompanion.insert(
                clientUuid: const drift.Value('tx-nov-16'),
                userEmail: const drift.Value(email),
                description: 'Academia',
                amount: 100.0,
                date: DateTime(2026, 11, 16),
                type: 'expense',
                category: 'Saúde',
              ),
            );
        await db.into(db.localTransactions).insert(
              LocalTransactionsCompanion.insert(
                clientUuid: const drift.Value('tx-nov-18'),
                userEmail: const drift.Value(email),
                description: 'Mercadinho Nov',
                amount: 50.0,
                date: DateTime(2026, 11, 18),
                type: 'expense',
                category: 'Alimentação',
              ),
            );
        await db.into(db.localTransactions).insert(
              LocalTransactionsCompanion.insert(
                clientUuid: const drift.Value('tx-mar-03'),
                userEmail: const drift.Value(email),
                description: 'Mercadinho Antigo',
                amount: 36.38,
                date: DateTime(2016, 3, 3),
                type: 'expense',
                category: 'Alimentação',
              ),
            );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              cloudSyncServiceProvider.overrideWithValue(mockSyncService),
            ],
            child: const GastoSyncApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          email,
        );
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Gasto@2026!',
        );
        await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Dashboard e TopBar Web sem textos removidos
        expect(find.text('Local sincronizado'), findsNothing);
        expect(find.text('Monitoramento Diário'), findsNothing);

        // Aba Transações com filtros de Mês e Dia
        await tester.tap(find.text('Transações').first);
        await tester.pumpAndSettle();

        expect(find.text('Academia'), findsOneWidget);
        expect(find.text('Mercadinho Nov'), findsOneWidget);
        expect(find.text('Mercadinho Antigo'), findsOneWidget);

        // Filtra por Mês: Novembro 2026
        await tester.tap(find.byKey(const Key('transactions_month_filter_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Novembro 2026').last);
        await tester.pumpAndSettle();

        expect(find.text('Academia'), findsOneWidget);
        expect(find.text('Mercadinho Nov'), findsOneWidget);
        expect(find.text('Mercadinho Antigo'), findsNothing);

        // Filtra por Dia: Dia 16
        await tester.tap(find.byKey(const Key('transactions_day_filter_button')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Dia 16').last);
        await tester.tap(find.text('Dia 16').last);
        await tester.pumpAndSettle();

        expect(find.text('Academia'), findsOneWidget);
        expect(find.text('Mercadinho Nov'), findsNothing);
        expect(find.text('Mercadinho Antigo'), findsNothing);

        // Limpa filtro de data
        await tester.tap(find.byKey(const Key('transactions_clear_date_filter_button')));
        await tester.pumpAndSettle();
        expect(find.text('Mercadinho Antigo'), findsOneWidget);

        // Aba Mais sem badges/textos técnicos removidos
        await tester.tap(find.text('Mais').first);
        await tester.pumpAndSettle();

        expect(find.text('Conta local ativa'), findsNothing);
        expect(find.text('Status da IA'), findsOneWidget);
        expect(find.textContaining('Limites da Cota'), findsNothing);
        expect(find.textContaining('Render Cloud'), findsNothing);
        expect(find.textContaining('Groq'), findsNothing);
        expect(find.textContaining('Tokens Processados'), findsNothing);
        expect(
          find.text('Exportar transações, boletos e cartões'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
