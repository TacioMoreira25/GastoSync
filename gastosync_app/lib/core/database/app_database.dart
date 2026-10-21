import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Tabela de Transações com suporte a sincronização offline-first
class LocalTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text().withLength(min: 1, max: 255)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // 'income' ou 'expense'
  TextColumn get category => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

/// Tabela de Metas e Limites Orçamentários
class LocalBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
}

/// Tabela de Snapshots de Métricas Consolidadas (9 Métricas de Saúde Financeira)
class LocalMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get calculatedAt => dateTime()();
  RealColumn get currentBalance => real()();
  RealColumn get totalIncome => real()();
  RealColumn get totalExpense => real()();
  RealColumn get savingsRate => real()();
  RealColumn get emergencyMonths => real()();
  RealColumn get incomeCommitment => real()();
  RealColumn get dailyBurnRate => real()();
  RealColumn get monthEndProjection => real()();
  RealColumn get healthScore => real()(); // 0 a 100
}

/// Tabela de Histórico de Insights do Agente de IA (Llama 3.3)
class LocalAgentInsights extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().nullable()();
  TextColumn get rawSuggestion => text()();
  RealColumn get confidenceScore => real()();
  TextColumn get categorySuggested => text()();
  TextColumn get budgetTip => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [
    LocalTransactions,
    LocalBudgets,
    LocalMetrics,
    LocalAgentInsights,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Stream reativa de todas as transações ordenadas por data
  Stream<List<LocalTransaction>> watchAllTransactions() {
    return (select(localTransactions)
          ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)]))
        .watch();
  }

  /// Inserção de nova transação
  Future<int> insertTransaction(LocalTransactionsCompanion entry) {
    return into(localTransactions).insert(entry);
  }

  /// Exclusão de transação por ID
  Future<int> deleteTransactionById(int transactionId) {
    return (delete(localTransactions)..where((t) => t.id.equals(transactionId))).go();
  }

  /// Atualização de status de sincronização com o backend
  Future<bool> markAsSynced(int transactionId) {
    return (update(localTransactions)..where((t) => t.id.equals(transactionId)))
        .write(const LocalTransactionsCompanion(isSynced: Value(true)))
        .then((rows) => rows > 0);
  }

  /// Inserção de snapshot das 9 métricas financeiras
  Future<int> insertMetricSnapshot(LocalMetricsCompanion entry) {
    return into(localMetrics).insert(entry);
  }

  /// Stream do último snapshot de métricas gravado
  Stream<LocalMetric?> watchLatestMetric() {
    return (select(localMetrics)
          ..orderBy([(m) => OrderingTerm.desc(m.calculatedAt), (m) => OrderingTerm.desc(m.id)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Inserção de novo insight do agente preditivo
  Future<int> insertAgentInsight(LocalAgentInsightsCompanion entry) {
    return into(localAgentInsights).insert(entry);
  }

  /// Stream do último insight do agente IA gravado
  Stream<LocalAgentInsight?> watchLatestAgentInsight() {
    return (select(localAgentInsights)
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt), (i) => OrderingTerm.desc(i.id)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Stream de todos os insights do agente IA ordenados por data
  Stream<List<LocalAgentInsight>> watchAllAgentInsights() {
    return (select(localAgentInsights)
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt), (i) => OrderingTerm.desc(i.id)]))
        .watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (kIsWeb) {
      return NativeDatabase.memory();
    }
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gastosync.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Provedor Riverpod para a instância do banco de dados Drift
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
