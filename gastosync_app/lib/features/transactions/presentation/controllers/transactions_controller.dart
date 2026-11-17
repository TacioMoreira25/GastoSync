import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../../settings/domain/models/user_profile.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/transaction.dart';

/// StreamProvider reativo consumindo o banco local Drift filtrado por conta logada (Fluxo A - 100% Offline-First)
final watchTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final auth = ref.watch(authProvider);
  final currentEmail = auth.currentEmail?.trim().toLowerCase();
  return repository.watchAllTransactions(userEmail: currentEmail);
});

/// StreamProvider reativo de boletos e contas a pagar (`LocalBills`) filtrado pela conta autenticada (T014)
final watchBillsProvider = StreamProvider<List<Bill>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final auth = ref.watch(authProvider);
  final currentEmail = auth.currentEmail?.trim().toLowerCase();
  return db
      .watchAllBills(userEmail: currentEmail)
      .map((rows) => rows.map(Bill.fromLocal).toList());
});

/// Contador reativo de boletos não pagos (pendentes ou vencidos) da conta ativa (T014)
final pendingBillsCountProvider = Provider<int>((ref) {
  final bills = ref.watch(watchBillsProvider).value ?? const <Bill>[];
  return bills.where((b) => !b.isDeleted && !b.isPaid).length;
});

/// Filtro de categoria selecionado na tela de transações
class SelectedCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selectCategory(String? category) {
    state = category;
  }
}

final selectedCategoryFilterProvider =
    NotifierProvider<SelectedCategoryFilterNotifier, String?>(
  SelectedCategoryFilterNotifier.new,
);

/// Sub-aba selecionada na tela de Transações (`0` = Lançamentos, `1` = Boletos a Pagar)
class TransactionsSubTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void selectSubTab(int index) {
    state = index.clamp(0, 1);
  }
}

final selectedTransactionsSubTabProvider =
    NotifierProvider<TransactionsSubTabNotifier, int>(
  TransactionsSubTabNotifier.new,
);

/// Categorias genéricas de fatura de cartão das quais os itens `isCreditCardCharge`
/// são deduzidos proporcionalmente para evitar dupla contagem no orçamento (FR-011b).
const Set<String> _genericCreditCardInvoiceCategories = <String>{
  'fatura',
  'fatura do cartão',
  'fatura do cartao',
  'fatura cartão',
  'fatura cartao',
  'cartão de crédito',
  'cartao de credito',
  'cartão',
  'cartao',
};

/// Agrega os gastos do mês por categoria (case-insensitive) aplicando a regra FR-011b (T014):
/// - Soma todas as despesas (`Transaction.isExpense`) do mês;
/// - Para cada item com `isCreditCardCharge == true` no mês, aloca o seu `amount` na
///   categoria vinculada (ex.: `saúde`, `lazer`) e deduz até o mesmo valor de
///   lançamentos genéricos de fatura de cartão para manter o total sem duplicidade.
Map<String, double> calculateAdjustedMonthlySpendingByCategory({
  required Iterable<Transaction> transactions,
  required Iterable<Bill> bills,
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  final spentByCategory = <String, double>{};

  for (final tx in transactions) {
    if (tx.isExpense &&
        tx.date.year == now.year &&
        tx.date.month == now.month) {
      final key = tx.category.trim().toLowerCase();
      if (key.isEmpty) continue;
      spentByCategory[key] = (spentByCategory[key] ?? 0.0) + tx.amount;
    }
  }

  for (final bill in bills) {
    if (bill.isDeleted || !bill.isCreditCardCharge) continue;
    if (bill.dueDate.year != now.year || bill.dueDate.month != now.month) {
      continue;
    }

    final targetKey = bill.category.trim().toLowerCase();
    if (targetKey.isEmpty || targetKey == 'renda') continue;

    // 1. Aloca o valor da cobrança fixa/recorrente do cartão na sua categoria real
    spentByCategory[targetKey] =
        (spentByCategory[targetKey] ?? 0.0) + bill.amount;

    // 2. Deduz proporcionalmente de qualquer lançamento genérico de fatura do cartão
    var remainingToDeduct = bill.amount;
    for (final invoiceKey in _genericCreditCardInvoiceCategories) {
      if (remainingToDeduct <= 0) break;
      if (invoiceKey == targetKey) continue;
      final currentInvoiceAmount = spentByCategory[invoiceKey] ?? 0.0;
      if (currentInvoiceAmount > 0) {
        final deduction = math.min(currentInvoiceAmount, remainingToDeduct);
        final updated = currentInvoiceAmount - deduction;
        if (updated <= 0.001) {
          spentByCategory.remove(invoiceKey);
        } else {
          spentByCategory[invoiceKey] = updated;
        }
        remainingToDeduct -= deduction;
      }
    }
  }

  return spentByCategory;
}

/// Provider reativo do gasto mensal por categoria já ajustado com cobranças no cartão (`isCreditCardCharge`)
final monthlyCategorySpendingProvider = Provider<Map<String, double>>((ref) {
  final transactions =
      ref.watch(watchTransactionsProvider).value ?? const <Transaction>[];
  final bills = ref.watch(watchBillsProvider).value ?? const <Bill>[];
  return calculateAdjustedMonthlySpendingByCategory(
    transactions: transactions,
    bills: bills,
  );
});

/// Controlador de ações de escrita para transações e boletos locais associados à conta ativa
class TransactionsController {
  TransactionsController(this._repository, this._db, this._ref);

  final TransactionRepository _repository;
  final AppDatabase _db;
  final Ref _ref;

  String? get _currentUserEmail {
    final authEmail = _ref.read(authProvider).currentEmail?.trim();
    if (authEmail != null && authEmail.isNotEmpty) {
      return authEmail.toLowerCase();
    }
    final profileEmail = _ref.read(userProfileProvider).email.trim();
    return profileEmail.isNotEmpty ? profileEmail.toLowerCase() : null;
  }

  /// Propaga imediatamente criações, edições e exclusões (tombstones) para a nuvem
  /// quando houver token JWT ativo, sem bloquear a resposta local (Offline-First).
  void _triggerBackgroundCloudSync() {
    final auth = _ref.read(authProvider);
    final token = auth.token;
    if (token == null || token.isEmpty) return;
    final email = auth.currentEmail?.trim().toLowerCase();
    unawaited(
      _ref
          .read(cloudSyncServiceProvider)
          .pushPendingTransactions(
            jwtToken: token,
            userEmail: email,
          )
          .catchError((_) => const CloudSyncResult(
                syncedCount: 0,
                isCloudSynced: false,
                message: '',
              )),
    );
  }

  Future<int> createManualTransaction({
    required String description,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String category,
    String paymentMethod = 'PIX',
    String? creditCardUuid,
  }) async {
    final email = _currentUserEmail;
    final transaction = Transaction(
      clientUuid: AppDatabase.generateClientUuid(),
      userEmail: email,
      description: description,
      amount: amount,
      date: date,
      type: type,
      category: category,
      paymentMethod: paymentMethod,
      creditCardUuid: creditCardUuid,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    final id = await _repository.addTransaction(transaction);
    _triggerBackgroundCloudSync();
    return id;
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final email = _currentUserEmail;
    final updated = transaction.copyWith(
      userEmail: transaction.userEmail ?? email,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    final rows = await _repository.updateTransaction(updated);
    _triggerBackgroundCloudSync();
    return rows;
  }

  Future<int> createAiConfirmedTransaction({
    required String description,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String category,
    required String rawSuggestion,
    required double confidenceScore,
    required String categorySuggested,
    required String budgetTip,
    String paymentMethod = 'PIX',
    String? creditCardUuid,
  }) async {
    final email = _currentUserEmail;
    final transaction = Transaction(
      clientUuid: AppDatabase.generateClientUuid(),
      userEmail: email,
      description: description,
      amount: amount,
      date: date,
      type: type,
      category: category,
      paymentMethod: paymentMethod,
      creditCardUuid: creditCardUuid,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    final id = await _repository.addTransactionWithAgentInsight(
      transaction: transaction,
      rawSuggestion: rawSuggestion,
      confidenceScore: confidenceScore,
      categorySuggested: categorySuggested,
      budgetTip: budgetTip,
    );
    _triggerBackgroundCloudSync();
    return id;
  }

  Future<void> deleteTransaction(int id) async {
    await _repository.deleteTransaction(id);
    _triggerBackgroundCloudSync();
  }

  /// Cria um novo boleto/conta a pagar (`LocalBills`) associado à conta ativa (T014)
  Future<int> createBill({
    required String description,
    required double amount,
    required DateTime dueDate,
    required String category,
    String barcode = '',
    bool isRecurring = false,
    bool isCreditCardCharge = false,
    String? creditCardUuid,
  }) async {
    final email = _currentUserEmail;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final initialStatus =
        targetDue.isBefore(today) ? BillStatus.overdue : BillStatus.pending;

    final bill = Bill(
      clientUuid: AppDatabase.generateClientUuid(),
      userEmail: email,
      description: description,
      amount: amount,
      dueDate: dueDate,
      category: category,
      barcode: barcode,
      isRecurring: isRecurring,
      isCreditCardCharge: isCreditCardCharge,
      creditCardUuid: creditCardUuid,
      status: initialStatus,
      isSynced: false,
      updatedAt: now,
    );

    final id = await _db.insertBill(bill.toCompanion());
    _triggerBackgroundCloudSync();
    return id;
  }

  /// Atualiza um boleto existente (`LocalBills`) (T014)
  Future<int> updateBill(Bill bill) async {
    if (bill.id == null) {
      throw ArgumentError('O ID do boleto é obrigatório para atualização.');
    }
    final updated = bill.copyWith(
      userEmail: bill.userEmail ?? _currentUserEmail,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    final rows = await _db.updateBill(bill.id!, updated.toCompanion());
    _triggerBackgroundCloudSync();
    return rows;
  }

  /// Remove um boleto por ID (soft delete por padrão para sincronização na nuvem) (T014)
  Future<int> deleteBill(int id, {bool softDelete = true}) async {
    final rows = await _db.deleteBillById(id, softDelete: softDelete);
    _triggerBackgroundCloudSync();
    return rows;
  }

  /// Dá baixa em um boleto (`payBillAndCreateTransaction`) (T014)
  Future<PayBillResult> payBill(int billId, {DateTime? paidAt}) async {
    final res = await _db.payBillAndCreateTransaction(billId, paidAt: paidAt);
    _triggerBackgroundCloudSync();
    return res;
  }

  /// Cria ou atualiza um cartão de crédito (`LocalCreditCards`) e dispara sync em nuvem.
  Future<int> upsertCreditCard({
    int? id,
    String? clientUuid,
    String? userEmail,
    required String name,
    required double limitAmount,
    double targetMinPercent = 50.0,
    double targetMaxPercent = 80.0,
    int dueDay = 10,
    bool isPrimary = false,
  }) async {
    final effectiveEmail = (userEmail ?? _currentUserEmail)?.trim().toLowerCase();
    final cardId = await _db.upsertCreditCard(
      id: id,
      clientUuid: clientUuid,
      userEmail: effectiveEmail,
      name: name,
      limitAmount: limitAmount,
      targetMinPercent: targetMinPercent,
      targetMaxPercent: targetMaxPercent,
      dueDay: dueDay,
      isPrimary: isPrimary,
    );
    _triggerBackgroundCloudSync();
    return cardId;
  }

  /// Remove um cartão de crédito (`LocalCreditCards`) via soft delete e dispara sync em nuvem.
  Future<int> deleteCreditCard(int cardId, {bool softDelete = true}) async {
    final rows = await _db.deleteCreditCard(cardId, softDelete: softDelete);
    _triggerBackgroundCloudSync();
    return rows;
  }
}

final transactionsControllerProvider = Provider<TransactionsController>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  return TransactionsController(repository, db, ref);
});
