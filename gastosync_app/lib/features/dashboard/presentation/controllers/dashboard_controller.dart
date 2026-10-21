import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../transactions/data/repositories/transaction_repository_impl.dart';
import '../../domain/services/financial_health_engine.dart';

/// StreamProvider reativo que observa transações do Drift, calcula as 9 métricas e persiste snapshot em LocalMetrics (T030)
final financialMetricsStreamProvider = StreamProvider<FinancialMetrics>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);

  return repository.watchAllTransactions().asyncMap((transactions) async {
    final metrics = FinancialHealthEngine.calculate(transactions);
    await db.insertMetricSnapshot(metrics.toCompanion());
    return metrics;
  });
});

/// StreamProvider reativo que emite o último insight salvo em LocalAgentInsights (T033)
final latestAgentInsightStreamProvider =
    StreamProvider<LocalAgentInsight?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchLatestAgentInsight();
});
