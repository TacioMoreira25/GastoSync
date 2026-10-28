import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/transaction.dart';

abstract class TransactionRepository {
  Stream<List<Transaction>> watchAllTransactions({String? userEmail});
  Future<int> addTransaction(Transaction transaction);
  Future<int> addTransactionWithAgentInsight({
    required Transaction transaction,
    required String rawSuggestion,
    required double confidenceScore,
    required String categorySuggested,
    required String budgetTip,
  });
  Future<void> deleteTransaction(int id);
  Future<bool> markAsSynced(int id);
}

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Stream<List<Transaction>> watchAllTransactions({String? userEmail}) {
    return _database.watchAllTransactions(userEmail: userEmail).map(
          (rows) => rows.map(Transaction.fromLocal).toList(),
        );
  }

  @override
  Future<int> addTransaction(Transaction transaction) {
    final companion = transaction.toCompanion();
    return _database.insertTransaction(companion);
  }

  @override
  Future<int> addTransactionWithAgentInsight({
    required Transaction transaction,
    required String rawSuggestion,
    required double confidenceScore,
    required String categorySuggested,
    required String budgetTip,
  }) async {
    return _database.transaction(() async {
      final txId = await _database.insertTransaction(transaction.toCompanion());
      await _database.insertAgentInsight(
        LocalAgentInsightsCompanion.insert(
          transactionId: drift.Value(txId),
          rawSuggestion: rawSuggestion,
          confidenceScore: confidenceScore,
          categorySuggested: categorySuggested,
          budgetTip: budgetTip,
          createdAt: DateTime.now(),
        ),
      );
      return txId;
    });
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await _database.deleteTransactionById(id);
  }

  @override
  Future<bool> markAsSynced(int id) {
    return _database.markAsSynced(id);
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepositoryImpl(db);
});
