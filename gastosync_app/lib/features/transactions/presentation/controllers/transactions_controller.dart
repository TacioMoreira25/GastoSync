import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/models/transaction.dart';

/// StreamProvider reativo consumindo o banco local Drift filtrado por conta logada (Fluxo A - 100% Offline-First)
final watchTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final auth = ref.watch(authProvider);
  final currentEmail = auth.currentEmail?.trim().toLowerCase();
  return repository.watchAllTransactions(userEmail: currentEmail);
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

/// Controlador de ações de escrita para transações locais associadas à conta ativa
class TransactionsController {
  TransactionsController(this._repository, this._ref);

  final TransactionRepository _repository;
  final Ref _ref;

  String? get _currentUserEmail =>
      _ref.read(authProvider).currentEmail?.trim().toLowerCase();

  Future<int> createManualTransaction({
    required String description,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String category,
  }) {
    final transaction = Transaction(
      userEmail: _currentUserEmail,
      description: description,
      amount: amount,
      date: date,
      type: type,
      category: category,
      isSynced: false,
    );
    return _repository.addTransaction(transaction);
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
  }) {
    final transaction = Transaction(
      userEmail: _currentUserEmail,
      description: description,
      amount: amount,
      date: date,
      type: type,
      category: category,
      isSynced: false,
    );
    return _repository.addTransactionWithAgentInsight(
      transaction: transaction,
      rawSuggestion: rawSuggestion,
      confidenceScore: confidenceScore,
      categorySuggested: categorySuggested,
      budgetTip: budgetTip,
    );
  }

  Future<void> deleteTransaction(int id) {
    return _repository.deleteTransaction(id);
  }
}

final transactionsControllerProvider = Provider<TransactionsController>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return TransactionsController(repository, ref);
});
