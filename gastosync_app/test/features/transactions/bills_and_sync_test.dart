import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/core/services/bill_notification_service.dart';
import 'package:gastosync_app/core/services/csv_export_service.dart';
import 'package:gastosync_app/features/planning/domain/models/credit_card_model.dart';
import 'package:gastosync_app/features/settings/domain/models/user_profile.dart';
import 'package:gastosync_app/features/transactions/domain/models/bill.dart';
import 'package:gastosync_app/features/transactions/domain/models/transaction.dart';
import 'package:gastosync_app/features/transactions/presentation/controllers/transactions_controller.dart';

class _TestUserProfileNotifier extends UserProfileNotifier {
  _TestUserProfileNotifier(this._initial);
  final UserProfile _initial;

  @override
  UserProfile build() => _initial;
}

void main() {
  group('002-pro-security-db-boletos — Unit & Widget Suite (T034)', () {
    late AppDatabase db;
    const testUserEmail = 'marcos.pereira@gastosync.local';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'US2: LocalBills payBillAndCreateTransaction dá baixa em boleto comum, cria despesa vinculada e agenda próximo mês se recorrente',
      () async {
        final dueDate = DateTime(2026, 11, 15);
        final billId = await db.insertBill(
          LocalBillsCompanion.insert(
            clientUuid: const drift.Value('bill-uuid-internet-01'),
            userEmail: const drift.Value(testUserEmail),
            description: 'Internet Fibra 600Mb',
            amount: 149.90,
            dueDate: dueDate,
            category: 'Moradia',
            barcode: const drift.Value('34191.79001 01043.510047 91020.150008 8 99990000014990'),
            isRecurring: const drift.Value(true),
            isCreditCardCharge: const drift.Value(false),
          ),
        );

        final payResult = await db.payBillAndCreateTransaction(
          billId,
          paidAt: DateTime(2026, 11, 14, 10, 30),
        );

        expect(payResult.paidBillId, equals(billId));
        expect(payResult.isCreditCardCharge, isFalse);
        expect(payResult.createdTransactionId, isNotNull);
        expect(payResult.nextRecurringBillId, isNotNull);

        // Verifica que a despesa foi criada com forma de pagamento 'Boleto' e valor exato
        final txs = await db.watchAllTransactions(userEmail: testUserEmail).first;
        final createdTx = txs.firstWhere((t) => t.id == payResult.createdTransactionId);
        expect(createdTx.description, equals('Internet Fibra 600Mb'));
        expect(createdTx.amount, closeTo(149.90, 0.001));
        expect(createdTx.paymentMethod, equals('Boleto'));
        expect(createdTx.category, equals('Moradia'));

        // Verifica que o boleto do mês seguinte foi gerado como pendente em 15/12/2026
        final bills = await db.watchAllBills(userEmail: testUserEmail).first;
        final paidBill = bills.firstWhere((b) => b.id == billId);
        final nextBill = bills.firstWhere((b) => b.id == payResult.nextRecurringBillId);

        expect(paidBill.status, equals('paid'));
        expect(paidBill.linkedTransactionId, equals(createdTx.id));
        expect(nextBill.status, equals('pending'));
        expect(nextBill.dueDate, equals(DateTime(2026, 12, 15)));
        expect(nextBill.amount, closeTo(149.90, 0.001));
        expect(nextBill.clientUuid, isNot(equals(paidBill.clientUuid)));
      },
    );

    test(
      'US2 / FR-011b: Cobrança recorrente no cartão (isCreditCardCharge=true) não duplica saída de caixa ao confirmar e realoca categoria no orçamento',
      () async {
        final now = DateTime(2026, 11, 12);

        // 1. Lança pagamento consolidado da fatura do cartão na categoria 'Cartão de Crédito' (R$ 1.000,00)
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('tx-fatura-nov'),
            userEmail: const drift.Value(testUserEmail),
            description: 'Pagamento Fatura Cartão Principal',
            amount: 1000.00,
            date: now,
            type: 'expense',
            category: 'Cartão de Crédito',
            paymentMethod: const drift.Value('PIX'),
          ),
        );

        // 2. Cadastra uma cobrança recorrente no cartão (Academia R$ 120,00 na categoria 'Saúde')
        // e um boleto bancário real (Condomínio R$ 450,00 na categoria 'Moradia')
        final cardBillId = await db.insertBill(
          LocalBillsCompanion.insert(
            clientUuid: const drift.Value('bill-card-gym'),
            userEmail: const drift.Value(testUserEmail),
            description: 'Academia Smart',
            amount: 120.00,
            dueDate: DateTime(2026, 11, 15),
            category: 'Saúde',
            isRecurring: const drift.Value(true),
            isCreditCardCharge: const drift.Value(true),
          ),
        );
        await db.insertBill(
          LocalBillsCompanion.insert(
            clientUuid: const drift.Value('bill-cash-condo'),
            userEmail: const drift.Value(testUserEmail),
            description: 'Condomínio Residencial',
            amount: 450.00,
            dueDate: DateTime(2026, 11, 20),
            category: 'Moradia',
            isRecurring: const drift.Value(false),
            isCreditCardCharge: const drift.Value(false),
          ),
        );

        final domainBills = (await db.watchAllBills(userEmail: testUserEmail).first)
            .map(Bill.fromLocal)
            .toList();

        // Total Real a Pagar deve considerar apenas o boleto bancário (R$ 450,00)
        expect(
          BillCalculations.calculateTotalPendingCashOutflow(domainBills),
          closeTo(450.00, 0.001),
        );
        // Inclusos na Fatura deve somar apenas a cobrança no cartão (R$ 120,00)
        expect(
          BillCalculations.calculateTotalCreditCardCharges(domainBills),
          closeTo(120.00, 0.001),
        );

        // Confirma a cobrança no cartão: NÃO deve criar nova transação de saída de caixa
        final result = await db.payBillAndCreateTransaction(
          cardBillId,
          paidAt: now,
        );
        expect(result.isCreditCardCharge, isTrue);
        expect(result.createdTransactionId, isNull);
        expect(result.nextRecurringBillId, isNotNull);

        // Verifica realocação de categoria no orçamento mensal (FR-011b):
        // 'Saúde' recebe R$ 120,00 e 'Cartão de Crédito' cai de R$ 1.000,00 para R$ 880,00
        final domainTxs = (await db.watchAllTransactions(userEmail: testUserEmail).first)
            .map(Transaction.fromLocal)
            .toList();
        final updatedBills = (await db.watchAllBills(userEmail: testUserEmail).first)
            .map(Bill.fromLocal)
            .toList();

        final adjusted = calculateAdjustedMonthlySpendingByCategory(
          transactions: domainTxs,
          bills: updatedBills,
          referenceDate: now,
        );

        expect(adjusted['saúde'], closeTo(120.00, 0.001));
        expect(adjusted['cartão de crédito'], closeTo(880.00, 0.001));
      },
    );

    test(
      'US5: LocalCreditCards e CreditCardUsageSummary calculam faixa saudável (50%–80%) e separam Fixas vs. Compras/Mercado',
      () async {
        final refDate = DateTime(2026, 11, 12);

        // Seed automático do Cartão Principal (limite R$ 1.500, faixa saudável 50%–80%)
        await db.seedDefaultCreditCardIfEmpty(userEmail: testUserEmail);
        final localCards =
            await db.watchAllCreditCards(userEmail: testUserEmail).first;
        expect(localCards.length, equals(1));

        final primaryCard = CreditCard.fromLocal(localCards.first);
        expect(primaryCard.name, equals('Cartão Principal'));
        expect(primaryCard.limitAmount, closeTo(1500.00, 0.001));
        expect(primaryCard.healthyMinAmount, closeTo(750.00, 0.001)); // 50%
        expect(primaryCard.healthyMaxAmount, closeTo(1200.00, 0.001)); // 80%

        // Cadastra Cartão Secundário (limite R$ 2.000, faixa 50%–75%)
        await db.upsertCreditCard(
          clientUuid: 'card-secondary-01',
          userEmail: testUserEmail,
          name: 'Cartão Secundário',
          limitAmount: 2000.00,
          targetMinPercent: 50.0,
          targetMaxPercent: 75.0,
          dueDay: 20,
          isPrimary: false,
        );

        final allCards = (await db.watchAllCreditCards(userEmail: testUserEmail).first)
            .map(CreditCard.fromLocal)
            .toList();
        expect(allCards.length, equals(2));

        // Cenário do Independent Test da US5:
        // Assinatura fixa (Academia R$ 120) + Compra de Mercado no crédito (R$ 680) = R$ 800 (53,33%)
        final bills = <Bill>[
          Bill(
            clientUuid: 'bill-gym-fixed',
            description: 'Academia Mensal',
            amount: 120.00,
            dueDate: DateTime(2026, 11, 10),
            category: 'Saúde',
            isRecurring: true,
            isCreditCardCharge: true,
            creditCardUuid: primaryCard.clientUuid,
          ),
        ];
        final transactions = <Transaction>[
          Transaction(
            clientUuid: 'tx-grocery-credit',
            description: 'Supermercado Mensal',
            amount: 680.00,
            date: DateTime(2026, 11, 11),
            type: TransactionType.expense,
            category: 'Alimentação',
            paymentMethod: 'Crédito',
            creditCardUuid: primaryCard.clientUuid,
          ),
        ];

        final summaries = CreditCardUsageSummary.calculateAll(
          cards: allCards,
          transactions: transactions,
          bills: bills,
          referenceDate: refDate,
        );

        final primarySummary = summaries.firstWhere(
          (s) => s.card.clientUuid == primaryCard.clientUuid,
        );

        expect(primarySummary.fixedSubscriptionsAmount, closeTo(120.00, 0.001));
        expect(primarySummary.variablePurchasesAmount, closeTo(680.00, 0.001));
        expect(primarySummary.totalUsedAmount, closeTo(800.00, 0.001));
        expect(primarySummary.utilizationPercent, closeTo(53.333, 0.01));
        expect(primarySummary.remainingHealthyMargin, closeTo(400.00, 0.001));
        expect(primarySummary.isInHealthySweetSpot, isTrue);
        expect(primarySummary.isAboveHealthyCeiling, isFalse);

        // Adiciona nova compra no crédito de R$ 500,00 -> Total R$ 1.300,00 (86,67% > 80% teto saudável)
        final overCeilingSummary = CreditCardUsageSummary.calculateForCard(
          card: primaryCard,
          transactions: [
            ...transactions,
            Transaction(
              clientUuid: 'tx-electronics-credit',
              description: 'Monitor USB-C',
              amount: 500.00,
              date: DateTime(2026, 11, 12),
              type: TransactionType.expense,
              category: 'Lazer',
              paymentMethod: 'Crédito',
              creditCardUuid: primaryCard.clientUuid,
            ),
          ],
          bills: bills,
          referenceDate: refDate,
        );

        expect(overCeilingSummary.totalUsedAmount, closeTo(1300.00, 0.001));
        expect(overCeilingSummary.isAboveHealthyCeiling, isTrue);
        expect(overCeilingSummary.isLimitExceeded, isFalse);
        expect(overCeilingSummary.amountAboveHealthyCeiling, closeTo(100.00, 0.001));
      },
    );

    test(
      'Contas novas iniciam sem nenhum cartão de crédito por padrão até o usuário cadastrar o seu primeiro',
      () async {
        const freshUser = 'novo.usuario@gastosync.local';
        final initialCards =
            await db.watchAllCreditCards(userEmail: freshUser).first;
        expect(initialCards, isEmpty);

        // Usuário cadastra seu primeiro cartão
        await db.upsertCreditCard(
          clientUuid: 'card-user-first',
          userEmail: freshUser,
          name: 'Meu Nubank',
          limitAmount: 2500.00,
          targetMinPercent: 50.0,
          targetMaxPercent: 80.0,
          dueDay: 15,
        );

        final afterInsert =
            await db.watchAllCreditCards(userEmail: freshUser).first;
        expect(afterInsert.length, equals(1));
        expect(afterInsert.first.name, equals('Meu Nubank'));
        expect(afterInsert.first.limitAmount, equals(2500.00));
        expect(afterInsert.first.isPrimary, isTrue); // Primeiro cartão torna-se principal automaticamente
      },
    );

    test(
      'US3: BillNotificationService dispara alertas 2x/dia nos turnos configurados sem duplicar no mesmo turno',
      () {
        const profile = UserProfile(
          fullName: 'Marcos Pereira',
          email: testUserEmail,
          monthlyBaseIncome: 8500.0,
          savingsRateTarget: 20.0,
          reminderTime1: '09:00',
          reminderTime2: '18:00',
        );

        final earlyMorning = DateTime(2026, 11, 12, 8, 30);
        final morning9am = DateTime(2026, 11, 12, 9, 5);
        final morning920 = DateTime(2026, 11, 12, 9, 20);
        final evening6pm = DateTime(2026, 11, 12, 18, 10);

        final bills = <Bill>[
          Bill(
            clientUuid: 'bill-due-today',
            description: 'Energia Elétrica',
            amount: 210.50,
            dueDate: DateTime(2026, 11, 12),
            category: 'Moradia',
          ),
          Bill(
            clientUuid: 'bill-due-in-2-days',
            description: 'Plano Celular',
            amount: 79.90,
            dueDate: DateTime(2026, 11, 14),
            category: 'Moradia',
          ),
        ];

        // Antes do 1º turno (08:30) -> nenhuma janela ativa
        expect(
          BillNotificationService.resolveActiveShiftWindow(
            earlyMorning,
            reminderTime1: profile.reminderTime1,
            reminderTime2: profile.reminderTime2,
          ),
          isNull,
        );

        // No 1º turno (09:05) -> janela 1 ativa
        final shift1 = BillNotificationService.resolveActiveShiftWindow(
          morning9am,
          reminderTime1: profile.reminderTime1,
          reminderTime2: profile.reminderTime2,
        );
        expect(shift1, isNotNull);
        expect(shift1!.shiftNumber, equals(1));

        // Resumo identifica 1 boleto hoje e 1 próximo
        final summary = BillNotificationService.summarizeActionableBills(
          bills,
          now: morning9am,
        );
        expect(summary.dueTodayBills.length, equals(1));
        expect(summary.upcomingBills.length, equals(1));
        expect(summary.totalActionableCount, equals(2));

        // Avaliação no container Riverpod com controle de deduplicação
        final container = ProviderContainer(
          overrides: [
            userProfileProvider.overrideWith(() => _TestUserProfileNotifier(profile)),
            watchBillsProvider.overrideWith((ref) => Stream.value(bills)),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(billNotificationServiceProvider.notifier);

        // Antes do horário (08:30) -> false
        expect(
          notifier.evaluateAndDispatchIfDue(
            profile: profile,
            bills: bills,
            now: earlyMorning,
          ),
          isFalse,
        );

        // 1º turno (09:05) -> true
        expect(
          notifier.evaluateAndDispatchIfDue(
            profile: profile,
            bills: bills,
            now: morning9am,
          ),
          isTrue,
        );

        // Mesmo 1º turno (09:20) -> false (deduplicado)
        expect(
          notifier.evaluateAndDispatchIfDue(
            profile: profile,
            bills: bills,
            now: morning920,
          ),
          isFalse,
        );

        // 2º turno (18:10) -> true (nova janela da noite)
        expect(
          notifier.evaluateAndDispatchIfDue(
            profile: profile,
            bills: bills,
            now: evening6pm,
          ),
          isTrue,
        );
      },
    );

    test(
      'US4: Persistência de paymentMethod, edição e soft delete (deletedAt) mantendo registro para sincronização',
      () async {
        final txId = await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('tx-edit-delete-01'),
            userEmail: const drift.Value(testUserEmail),
            description: 'Compra Farmácia',
            amount: 85.40,
            date: DateTime(2026, 11, 10),
            type: 'expense',
            category: 'Saúde',
            paymentMethod: const drift.Value('Débito'),
            isSynced: const drift.Value(true),
          ),
        );

        // Edita valor e forma de pagamento para 'Crédito'
        await db.updateTransaction(
          txId,
          const LocalTransactionsCompanion(
            amount: drift.Value(92.75),
            paymentMethod: drift.Value('Crédito'),
            creditCardUuid: drift.Value('card-main-uuid'),
            isSynced: drift.Value(false),
          ),
        );

        final afterEdit =
            (await db.watchAllTransactions(userEmail: testUserEmail).first)
                .firstWhere((t) => t.id == txId);
        expect(afterEdit.amount, closeTo(92.75, 0.001));
        expect(afterEdit.paymentMethod, equals('Crédito'));
        expect(afterEdit.creditCardUuid, equals('card-main-uuid'));
        expect(afterEdit.isSynced, isFalse);

        // Soft delete: oculta de watchAllTransactions mas mantém em getPendingSyncTransactions
        await db.deleteTransactionById(txId, softDelete: true);
        final activeAfterDelete =
            await db.watchAllTransactions(userEmail: testUserEmail).first;
        expect(activeAfterDelete.where((t) => t.id == txId), isEmpty);

        final pendingForSync =
            await db.getPendingSyncTransactions(userEmail: testUserEmail);
        final softDeletedRow =
            pendingForSync.firstWhere((t) => t.id == txId);
        expect(softDeletedRow.deletedAt, isNotNull);
        expect(softDeletedRow.isSynced, isFalse);
      },
    );

    test(
      'US6: CsvExportService gera relatório RFC-4180 com UTF-8 BOM, escapa vírgulas/aspas e neutraliza Formula Injection',
      () {
        final card = CreditCard(
          clientUuid: 'card-1',
          name: 'Cartão Principal',
          limitAmount: 1500.0,
          targetMinPercent: 50.0,
          targetMaxPercent: 80.0,
          dueDay: 10,
          isPrimary: true,
        );
        final tx = Transaction(
          clientUuid: 'tx-csv-1',
          description: 'Mercado "Bom Preço", Centro',
          amount: 680.00,
          date: DateTime(2026, 11, 11),
          type: TransactionType.expense,
          category: 'Alimentação',
          paymentMethod: 'Crédito',
          creditCardUuid: card.clientUuid,
          isSynced: true,
        );
        final formulaBill = Bill(
          clientUuid: 'bill-csv-1',
          description: '=SUM(A1:A10)',
          amount: 120.00,
          dueDate: DateTime(2026, 11, 15),
          category: 'Saúde',
          isRecurring: true,
          isCreditCardCharge: true,
          creditCardUuid: card.clientUuid,
        );

        final report = CsvExportService.generateConsolidatedReport(
          transactions: [tx],
          bills: [formulaBill],
          creditCards: [card],
          userEmail: testUserEmail,
          referenceDate: DateTime(2026, 11, 12, 14, 30),
        );

        expect(report.csvContent.startsWith(CsvExportService.utf8Bom), isTrue);
        expect(report.csvContent.contains('\r\n'), isTrue);
        expect(
          report.csvContent.contains('"Mercado ""Bom Preço"", Centro"'),
          isTrue,
        );
        expect(report.csvContent.contains("'=SUM(A1:A10)"), isTrue);
        expect(report.csvContent.contains('TRANSACAO'), isTrue);
        expect(report.csvContent.contains('BOLETO'), isTrue);
        expect(report.csvContent.contains('CARTAO_LIMITE'), isTrue);
        expect(report.totalRecordsCount, equals(3));
      },
    );

    testWidgets(
      'US6 Widget Test: Modal de exportação CSV exibe abas Consolidado, Transações, Boletos e Cartões',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final card = CreditCard(
          clientUuid: 'card-widget-1',
          name: 'Cartão Principal',
          limitAmount: 1500.0,
        );
        final tx = Transaction(
          clientUuid: 'tx-widget-1',
          description: 'Padaria Central',
          amount: 45.00,
          date: DateTime(2026, 11, 12),
          type: TransactionType.expense,
          category: 'Alimentação',
          paymentMethod: 'PIX',
        );
        final bill = Bill(
          clientUuid: 'bill-widget-1',
          description: 'Energia',
          amount: 180.00,
          dueDate: DateTime(2026, 11, 20),
          category: 'Moradia',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    key: const Key('open_csv_modal_btn'),
                    onPressed: () => CsvExportService.showExportModal(
                      context,
                      transactions: [tx],
                      bills: [bill],
                      creditCards: [card],
                      userEmail: testUserEmail,
                    ),
                    child: const Text('Exportar'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open_csv_modal_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('csv_export_preview_dialog')), findsOneWidget);
        expect(find.byKey(const Key('csv_tab_consolidated')), findsOneWidget);
        expect(find.byKey(const Key('csv_tab_transactions')), findsOneWidget);
        expect(find.byKey(const Key('csv_tab_bills')), findsOneWidget);
        expect(find.byKey(const Key('csv_tab_cards')), findsOneWidget);

        await tester.tap(find.byKey(const Key('csv_tab_cards')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Cartão Principal'), findsWidgets);
      },
    );
  });
}
