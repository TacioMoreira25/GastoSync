import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/core/network/dio_client.dart';
import 'package:gastosync_app/features/dashboard/domain/services/financial_health_engine.dart';
import 'package:gastosync_app/features/transactions/domain/models/transaction.dart';
import 'package:gastosync_app/features/transactions/presentation/controllers/transactions_controller.dart';
import 'package:gastosync_app/main.dart';

void main() {
  group('Multiplatform Regression & Offline Resilience Tests (T034, T035)', () {
    test('FinancialHealthEngine calcula matematicamente todas as 9 métricas (US4)', () {
      final refDate = DateTime(2026, 10, 15); // Dia 15 de um mês de 31 dias
      final transactions = [
        Transaction(
          id: 1,
          description: 'Salário Outubro',
          amount: 10000.0,
          date: DateTime(2026, 10, 5),
          type: TransactionType.income,
          category: 'Renda Principal',
        ),
        Transaction(
          id: 2,
          description: 'Despesas Outubro',
          amount: 3000.0,
          date: DateTime(2026, 10, 10),
          type: TransactionType.expense,
          category: 'Moradia',
        ),
        Transaction(
          id: 3,
          description: 'Reserva Acumulada Setembro',
          amount: 11000.0,
          date: DateTime(2026, 9, 10),
          type: TransactionType.income,
          category: 'Investimentos',
        ),
      ];

      final metrics = FinancialHealthEngine.calculate(
        transactions,
        referenceDate: refDate,
      );

      // 1. Saldo Líquido Acumulado: 10000 - 3000 + 11000 = 18000
      expect(metrics.currentBalance, closeTo(18000.0, 0.01));
      // 2. Receita Mensal (Outubro): 10000
      expect(metrics.totalIncome, closeTo(10000.0, 0.01));
      // 3. Despesa Mensal (Outubro): 3000
      expect(metrics.totalExpense, closeTo(3000.0, 0.01));
      // 4. Taxa de Poupança (%): (10000 - 3000) / 10000 * 100 = 70%
      expect(metrics.savingsRate, closeTo(70.0, 0.01));
      // 5. Reserva em Meses: 18000 / 3000 = 6.0 meses
      expect(metrics.emergencyMonths, closeTo(6.0, 0.01));
      // 6. Comprometimento da Renda (%): 3000 / 10000 * 100 = 30%
      expect(metrics.incomeCommitment, closeTo(30.0, 0.01));
      // 7. Burn Rate Diário: 3000 / 15 dias = 200/dia
      expect(metrics.dailyBurnRate, closeTo(200.0, 0.01));
      // 8. Projeção de Fim de Mês (31 dias -> 16 restantes): 3000 + 200 * 16 = 6200
      expect(metrics.monthEndProjection, closeTo(6200.0, 0.01));
      // 9. Score: (70 * 0.3) + (1.0 * 35) + (0.7 * 35) = 21 + 35 + 24.5 = 80.5
      expect(metrics.healthScore, closeTo(80.5, 0.01));
      expect(metrics.sixMonthsSeries.length, equals(6));
    });

    testWidgets(
      'Responsividade Multiplataforma: Mobile (360dp NavigationBar) vs Web/Desktop (1280dp NavigationRail) (T034)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());

        // 1. Mobile Viewport (360x800)
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: const GastoSyncApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);

        // 2. Web / Desktop Viewport (1280x900)
        tester.view.physicalSize = const Size(1280, 900);
        await tester.pumpAndSettle();

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    test(
      'Persistência Offline sob perda súbita de conexão garante gravação íntegra no Drift (T035)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());

        // Simula perda total de rede no Dio
        final offlineDio = Dio();
        offlineDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'Simulated sudden network loss',
                ),
              );
            },
          ),
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            dioProvider.overrideWithValue(offlineDio),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(transactionsControllerProvider);

        // Mesmo sem rede, a escrita local funciona instantaneamente com isSynced = false
        final txId = await controller.createManualTransaction(
          description: 'Supermercado Modo Avião',
          amount: 150.0,
          date: DateTime(2026, 10, 20),
          type: TransactionType.expense,
          category: 'Alimentação',
        );

        expect(txId, greaterThan(0));
        final savedList = await db.watchAllTransactions().first;
        expect(savedList.length, equals(1));
        expect(savedList.first.description, equals('Supermercado Modo Avião'));
        expect(savedList.first.isSynced, isFalse);
      },
    );
  });
}
