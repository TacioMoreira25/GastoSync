import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/features/planning/domain/models/credit_card_model.dart';
import 'package:gastosync_app/features/transactions/domain/models/bill.dart';
import 'package:gastosync_app/features/transactions/domain/models/transaction.dart';
import 'package:gastosync_app/features/transactions/presentation/controllers/transactions_controller.dart';

void main() {
  group('Pacote 1 — Parcelamentos, Estorno de Boleto e Fatura Manual do Cartão', () {
    late AppDatabase db;
    const userEmail = 'teste@gastosync.local';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('addMonthsClamped ajusta corretamente dias 29/30/31 em meses mais curtos', () {
      final jan31 = DateTime(2026, 1, 31);
      expect(
        TransactionsController.addMonthsClamped(jan31, 1),
        equals(DateTime(2026, 2, 28)),
      );
      expect(
        TransactionsController.addMonthsClamped(jan31, 2),
        equals(DateTime(2026, 3, 31)),
      );
      expect(
        TransactionsController.addMonthsClamped(jan31, 3),
        equals(DateTime(2026, 4, 30)),
      );
    });

    test('splitInstallmentAmounts divide valor total preservando centavos exatos', () {
      final parcels = TransactionsController.splitInstallmentAmounts(
        inputAmount: 100.0,
        installments: 3,
        inputIsTotal: true,
      );
      expect(parcels, equals([33.33, 33.33, 33.34]));
      expect(
        parcels.fold<double>(0.0, (a, b) => a + b),
        closeTo(100.0, 0.0001),
      );

      final fixedParcels = TransactionsController.splitInstallmentAmounts(
        inputAmount: 120.50,
        installments: 4,
        inputIsTotal: false,
      );
      expect(fixedParcels, equals([120.50, 120.50, 120.50, 120.50]));
    });

    test('unpayBillAndRevertTransaction reverte status do boleto e faz soft-delete da despesa vinculada', () async {
      final futureDue = DateTime.now().add(const Duration(days: 5));
      final billId = await db.insertBill(
        LocalBillsCompanion.insert(
          clientUuid: const drift.Value('bill-estorno-01'),
          userEmail: const drift.Value(userEmail),
          description: 'Notebook (1/12)',
          amount: 350.0,
          dueDate: futureDue,
          category: 'Outros',
        ),
      );

      final payRes = await db.payBillAndCreateTransaction(billId);
      expect(payRes.createdTransactionId, isNotNull);

      var activeTxs = await db.watchAllTransactions(userEmail: userEmail).first;
      expect(activeTxs.length, equals(1));

      final reverted = await db.unpayBillAndRevertTransaction(billId);
      expect(reverted, isTrue);

      final bills = await db.watchAllBills(userEmail: userEmail).first;
      final bill = bills.firstWhere((b) => b.id == billId);
      expect(bill.status, equals('pending'));
      expect(bill.paidAt, isNull);
      expect(bill.linkedTransactionId, isNull);
      expect(bill.isSynced, isFalse);

      // Despesa vinculada não aparece mais nas ativas, mas existe como tombstone (deletedAt != null) para sincronizar exclusão
      activeTxs = await db.watchAllTransactions(userEmail: userEmail).first;
      expect(activeTxs, isEmpty);

      final allTxs = await db.getAllTransactionsIncludingDeleted(userEmail: userEmail);
      expect(allTxs.length, equals(1));
      expect(allTxs.first.deletedAt, isNotNull);
      expect(allTxs.first.isSynced, isFalse);
    });

    test('Fatura manual do cartão prevalece no mês vigente sem conflitar com compras e volta ao automático ao virar o mês ou resetar', () async {
      final cardId = await db.upsertCreditCard(
        userEmail: userEmail,
        name: 'Nubank',
        limitAmount: 2000.0,
        dueDay: 28,
        closingDay: 20,
        isPrimary: true,
      );

      final nov2026 = DateTime(2026, 11, 15);
      final dec2026 = DateTime(2026, 12, 5);

      await db.updateCreditCardManualInvoice(
        cardId,
        manualInvoiceAmount: 1250.0,
        manualInvoiceMonth: '2026-11',
      );

      final localCards = await db.watchAllCreditCards(userEmail: userEmail).first;
      final card = CreditCard.fromLocal(localCards.first);

      final txs = [
        Transaction(
          id: 1,
          clientUuid: 'tx-1',
          userEmail: userEmail,
          description: 'Mercado',
          amount: 200.0,
          date: nov2026,
          type: TransactionType.expense,
          category: 'Alimentação',
          paymentMethod: 'Crédito',
          creditCardUuid: card.clientUuid,
        ),
      ];
      final bills = [
        Bill(
          id: 1,
          clientUuid: 'bill-1',
          userEmail: userEmail,
          description: 'Streaming',
          amount: 50.0,
          dueDate: nov2026,
          category: 'Lazer',
          isCreditCardCharge: true,
          creditCardUuid: card.clientUuid,
        ),
      ];

      // Em Nov/2026: usa fatura manual (1250), mantém detalhamento (250) e calcula diferença (1000)
      final novSummary = CreditCardUsageSummary.calculateForCard(
        card: card,
        transactions: txs,
        bills: bills,
        referenceDate: nov2026,
      );
      expect(novSummary.hasManualInvoice, isTrue);
      expect(novSummary.totalUsedAmount, closeTo(1250.0, 0.001));
      expect(novSummary.trackedUsedAmount, closeTo(250.0, 0.001));
      expect(novSummary.untrackedInvoiceDifference, closeTo(1000.0, 0.001));

      // Em Dez/2026: expira automaticamente e volta ao cálculo automático (0.0)
      final decSummary = CreditCardUsageSummary.calculateForCard(
        card: card,
        transactions: txs,
        bills: bills,
        referenceDate: dec2026,
      );
      expect(decSummary.hasManualInvoice, isFalse);
      expect(decSummary.totalUsedAmount, closeTo(0.0, 0.001));

      // Reset manual volta imediatamente para 250.0 no mês vigente
      await db.updateCreditCardManualInvoice(
        cardId,
        manualInvoiceAmount: null,
        manualInvoiceMonth: null,
      );
      final resetCard = CreditCard.fromLocal(
        (await db.watchAllCreditCards(userEmail: userEmail).first).first,
      );
      final resetSummary = CreditCardUsageSummary.calculateForCard(
        card: resetCard,
        transactions: txs,
        bills: bills,
        referenceDate: nov2026,
      );
      expect(resetSummary.hasManualInvoice, isFalse);
      expect(resetSummary.totalUsedAmount, closeTo(250.0, 0.001));
    });
  });
}
