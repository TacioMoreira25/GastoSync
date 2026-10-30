import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection.dart' as impl;

part 'app_database.g.dart';

/// Tabela de Transações com suporte a sincronização offline-first e isolamento por conta
class LocalTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
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
  AppDatabase() : super(impl.constructDb());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(localTransactions, localTransactions.userEmail);
          }
        },
      );

  /// Seed padrão de metas mensais por categoria conforme protótipo Figma v2 (T044)
  static const Map<String, double> defaultCategoryBudgets = <String, double>{
    'Alimentação': 1200.0,
    'Moradia': 1800.0,
    'Transporte': 600.0,
    'Lazer': 500.0,
  };

  /// Stream reativa de transações filtradas por conta (`userEmail`) ordenadas por data
  Stream<List<LocalTransaction>> watchAllTransactions({String? userEmail}) {
    final query = select(localTransactions);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final normalized = userEmail.trim().toLowerCase();
      query.where((t) => t.userEmail.equals(normalized));
    }
    return (query
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.id),
          ]))
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

  /// Garante a persistência inicial do seed padrão na tabela `LocalBudgets` caso esteja vazia
  Future<void> seedDefaultBudgetsIfEmpty({int? month, int? year}) async {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final existing = await (select(localBudgets)
          ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear)))
        .get();

    if (existing.isNotEmpty) return;

    await batch((b) {
      for (final entry in defaultCategoryBudgets.entries) {
        b.insert(
          localBudgets,
          LocalBudgetsCompanion.insert(
            category: entry.key,
            limitAmount: entry.value,
            month: targetMonth,
            year: targetYear,
          ),
        );
      }
    });
  }

  /// Stream reativa de todas as metas mensais (`LocalBudgets`) com seed padrão
  /// para `Alimentação`, `Moradia`, `Transporte` e `Lazer` (T044)
  Stream<List<LocalBudget>> watchAllBudgets({int? month, int? year}) {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final query = select(localBudgets)
      ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear))
      ..orderBy([(b) => OrderingTerm.asc(b.id)]);

    return query.watch().map((persistedRows) {
      final byCategory = <String, LocalBudget>{};

      var syntheticId = -1;
      for (final entry in defaultCategoryBudgets.entries) {
        byCategory[entry.key.toLowerCase()] = LocalBudget(
          id: syntheticId--,
          category: entry.key,
          limitAmount: entry.value,
          month: targetMonth,
          year: targetYear,
        );
      }

      for (final row in persistedRows) {
        final key = row.category.trim().toLowerCase();
        if (row.limitAmount <= 0) {
          // Categoria removida explicitamente pelo usuário
          byCategory.remove(key);
        } else {
          byCategory[key] = row;
        }
      }

      return byCategory.values.toList();
    });
  }

  /// Lista as categorias cujo orçamento foi explicitamente excluído pelo usuário (`limitAmount <= 0`)
  Stream<Set<String>> watchDeletedBudgetCategories({int? month, int? year}) {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final query = select(localBudgets)
      ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear));

    return query.watch().map((rows) {
      return {
        for (final r in rows)
          if (r.limitAmount <= 0) r.category.trim().toLowerCase(),
      };
    });
  }

  /// Insere ou atualiza o teto orçamentário mensal de uma categoria (`upsertBudget`) (T044)
  Future<int> upsertBudget({
    required String category,
    required double limitAmount,
    int? month,
    int? year,
  }) async {
    final normalizedCategory = category.trim();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final existingRows = await (select(localBudgets)
          ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear)))
        .get();

    final match = existingRows
        .where(
          (b) => b.category.trim().toLowerCase() == normalizedCategory.toLowerCase(),
        )
        .firstOrNull;

    if (match != null) {
      await (update(localBudgets)..where((b) => b.id.equals(match.id))).write(
        LocalBudgetsCompanion(
          category: Value(normalizedCategory),
          limitAmount: Value(limitAmount),
        ),
      );
      return match.id;
    }

    return into(localBudgets).insert(
      LocalBudgetsCompanion.insert(
        category: normalizedCategory,
        limitAmount: limitAmount,
        month: targetMonth,
        year: targetYear,
      ),
    );
  }

  /// Garante que uma nova categoria criada via transação exista em `LocalBudgets` caso ainda não exista
  Future<void> ensureCategoryBudgetExists(
    String category, {
    double defaultLimit = 500.0,
    int? month,
    int? year,
  }) async {
    final normalized = category.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'renda') return;

    final isDefault = defaultCategoryBudgets.keys.any(
      (k) => k.toLowerCase() == normalized.toLowerCase(),
    );
    if (isDefault) return;

    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final existingRows = await (select(localBudgets)
          ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear)))
        .get();

    final alreadyExists = existingRows.any(
      (b) => b.category.trim().toLowerCase() == normalized.toLowerCase(),
    );

    if (!alreadyExists) {
      await into(localBudgets).insert(
        LocalBudgetsCompanion.insert(
          category: normalized,
          limitAmount: defaultLimit,
          month: targetMonth,
          year: targetYear,
        ),
      );
    }
  }

  /// Remove uma categoria/meta de `LocalBudgets` (marca com `limitAmount = -1` para ocultar inclusive categorias padrão)
  Future<void> deleteBudgetByCategory(
    String category, {
    int? month,
    int? year,
  }) async {
    final normalizedCategory = category.trim();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final existingRows = await (select(localBudgets)
          ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear)))
        .get();

    final match = existingRows
        .where(
          (b) => b.category.trim().toLowerCase() == normalizedCategory.toLowerCase(),
        )
        .firstOrNull;

    if (match != null) {
      await (update(localBudgets)..where((b) => b.id.equals(match.id))).write(
        const LocalBudgetsCompanion(
          limitAmount: Value(-1.0),
        ),
      );
      return;
    }

    await into(localBudgets).insert(
      LocalBudgetsCompanion.insert(
        category: normalizedCategory,
        limitAmount: -1.0,
        month: targetMonth,
        year: targetYear,
      ),
    );
  }

  /// Inicializa tabelas dinâmicas de contas locais e sessão autenticada (persistência 100% SQLite)
  Future<void> initCustomAuthTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_auth_accounts (
        email TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        salt TEXT NOT NULL,
        password_hash TEXT NOT NULL
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        current_email TEXT,
        is_authenticated INTEGER NOT NULL DEFAULT 0,
        jwt_token TEXT
      );
    ''');
    try {
      await customStatement(
        'ALTER TABLE local_auth_session ADD COLUMN jwt_token TEXT;',
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getPersistedAuthAccounts() async {
    await initCustomAuthTables();
    final rows = await customSelect(
      'SELECT email, full_name, salt, password_hash FROM local_auth_accounts',
    ).get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> saveAuthAccount({
    required String email,
    required String fullName,
    required String salt,
    required String passwordHash,
  }) async {
    await initCustomAuthTables();
    await customStatement(
      'INSERT OR REPLACE INTO local_auth_accounts (email, full_name, salt, password_hash) VALUES (?, ?, ?, ?);',
      [email.trim().toLowerCase(), fullName.trim(), salt, passwordHash],
    );
  }

  Future<void> updateAuthPassword({
    required String email,
    required String salt,
    required String passwordHash,
  }) async {
    await initCustomAuthTables();
    await customStatement(
      'UPDATE local_auth_accounts SET salt = ?, password_hash = ? WHERE email = ?;',
      [salt, passwordHash, email.trim().toLowerCase()],
    );
  }

  Future<void> saveAuthSession({
    required String? currentEmail,
    required bool isAuthenticated,
    String? jwtToken,
  }) async {
    await initCustomAuthTables();
    await customStatement(
      'INSERT OR REPLACE INTO local_auth_session (id, current_email, is_authenticated, jwt_token) VALUES (1, ?, ?, ?);',
      [currentEmail, isAuthenticated ? 1 : 0, jwtToken],
    );
  }

  Future<Map<String, dynamic>?> getPersistedAuthSession() async {
    await initCustomAuthTables();
    final rows = await customSelect(
      'SELECT current_email, is_authenticated, jwt_token FROM local_auth_session WHERE id = 1',
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.data;
  }
}

/// Provedor Riverpod para a instância do banco de dados Drift
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// StreamProvider reativo das metas mensais (`LocalBudgets`) com seed padrão
final watchBudgetsProvider = StreamProvider<List<LocalBudget>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllBudgets();
});

/// StreamProvider reativo das categorias de metas excluídas pelo usuário
final watchDeletedBudgetCategoriesProvider = StreamProvider<Set<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDeletedBudgetCategories();
});
