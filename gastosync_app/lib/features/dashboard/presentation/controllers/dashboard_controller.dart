import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../../transactions/data/repositories/transaction_repository_impl.dart';
import '../../domain/services/financial_health_engine.dart';

/// StreamProvider reativo que observa transações da conta ativa, calcula as 9 métricas e persiste snapshot em LocalMetrics (T030)
final financialMetricsStreamProvider = StreamProvider<FinancialMetrics>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final auth = ref.watch(authProvider);
  final currentEmail = auth.currentEmail?.trim().toLowerCase();
  final db = ref.watch(appDatabaseProvider);

  return repository
      .watchAllTransactions(userEmail: currentEmail)
      .asyncMap((transactions) async {
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
