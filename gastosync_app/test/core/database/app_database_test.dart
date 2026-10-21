import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('AppDatabase Drift Persistence & Streams (T005-T008, T011, T035)', () {
    test('Deve inserir e recuperar transação com stream reativa', () async {
      final entry = LocalTransactionsCompanion(
        description: const drift.Value('Salário Mensal'),
        amount: const drift.Value(15000.0),
        date: drift.Value(DateTime(2026, 10, 20)),
        type: const drift.Value('income'),
        category: const drift.Value('Renda Principal'),
        isSynced: const drift.Value(false),
      );

      final id = await database.insertTransaction(entry);
      expect(id, equals(1));

      final list = await database.watchAllTransactions().first;
      expect(list.length, equals(1));
      expect(list.first.description, equals('Salário Mensal'));
      expect(list.first.amount, equals(15000.0));
      expect(list.first.isSynced, isFalse);
    });

    test('Deve persistir snapshots em LocalMetrics e emitir último registro', () async {
      await database.insertMetricSnapshot(
        LocalMetricsCompanion.insert(
          calculatedAt: DateTime(2026, 10, 20, 12, 0),
          currentBalance: 8500.0,
          totalIncome: 12000.0,
          totalExpense: 3500.0,
          savingsRate: 70.83,
          emergencyMonths: 2.42,
          incomeCommitment: 29.17,
          dailyBurnRate: 175.0,
          monthEndProjection: 5425.0,
          healthScore: 80.2,
        ),
      );

      final latest = await database.watchLatestMetric().first;
      expect(latest, isNotNull);
      expect(latest!.currentBalance, equals(8500.0));
      expect(latest.healthScore, closeTo(80.2, 0.01));
    });

    test('Deve persistir sugestões da IA em LocalAgentInsights', () async {
      final insightId = await database.insertAgentInsight(
        LocalAgentInsightsCompanion.insert(
          transactionId: const drift.Value(1),
          rawSuggestion: '{"category":"Alimentação","confidence":0.94}',
          confidenceScore: 0.94,
          categorySuggested: 'Alimentação',
          budgetTip: 'Gastos com alimentação em 72% da meta.',
          createdAt: DateTime(2026, 10, 20, 14, 30),
        ),
      );

      expect(insightId, equals(1));
      final latest = await database.watchLatestAgentInsight().first;
      expect(latest, isNotNull);
      expect(latest!.categorySuggested, equals('Alimentação'));
      expect(latest.confidenceScore, closeTo(0.94, 0.001));
    });
  });
}
