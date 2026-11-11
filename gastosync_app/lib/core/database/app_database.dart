import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection.dart' as impl;

part 'app_database.g.dart';

/// Resultado estruturado da baixa transacional de um boleto (`payBillAndCreateTransaction`)
class PayBillResult {
  const PayBillResult({
    required this.paidBillId,
    required this.isCreditCardCharge,
    this.createdTransactionId,
    this.createdTransactionUuid,
    this.nextRecurringBillId,
  });

  final int paidBillId;
  final bool isCreditCardCharge;
  final int? createdTransactionId;
  final String? createdTransactionUuid;
  final int? nextRecurringBillId;
}

/// Tabela de Transações com suporte a sincronização offline-first, UUID, forma de pagamento, vínculo de cartão e soft delete (Schema v3)
class LocalTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().withDefault(const Constant(''))();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
  TextColumn get description => text().withLength(min: 1, max: 255)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // 'income' ou 'expense'
  TextColumn get category => text()();
  TextColumn get paymentMethod => text().withDefault(const Constant('PIX'))();
  TextColumn get creditCardUuid => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Tabela de Boletos e Contas a Pagar com suporte a linha digitável/PIX, recorrência mensal e cobranças embutidas na fatura do cartão (Schema v3)
class LocalBills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().withDefault(const Constant(''))();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
  TextColumn get description => text().withLength(min: 1, max: 255)();
  RealColumn get amount => real()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get category => text()();
  TextColumn get barcode => text().withDefault(const Constant(''))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isCreditCardCharge =>
      boolean().withDefault(const Constant(false))();
  TextColumn get creditCardUuid => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // 'pending', 'paid', 'overdue'
  DateTimeColumn get paidAt => dateTime().nullable()();
  IntColumn get linkedTransactionId => integer().nullable()();
  TextColumn get linkedTxUuid => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Tabela de Cartões de Crédito com limite e faixa saudável de relacionamento bancário (50% a 80%) (Schema v3)
class LocalCreditCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientUuid => text().withDefault(const Constant(''))();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get limitAmount => real()();
  RealColumn get targetMinPercent =>
      real().withDefault(const Constant(50.0))();
  RealColumn get targetMaxPercent =>
      real().withDefault(const Constant(80.0))();
  IntColumn get dueDay => integer().withDefault(const Constant(10))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Tabela de Metas e Limites Orçamentários isolada por conta (`userEmail`)
class LocalBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
}

/// Tabela de Snapshots de Métricas Consolidadas (9 Métricas de Saúde Financeira) isolada por conta (`userEmail`)
class LocalMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
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

/// Tabela de Histórico de Insights do Agente de IA (Llama 3.3) isolada por conta (`userEmail`)
class LocalAgentInsights extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userEmail =>
      text().withDefault(const Constant('marcos.pereira@gastosync.local'))();
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
    LocalBills,
    LocalCreditCards,
    LocalBudgets,
    LocalMetrics,
    LocalAgentInsights,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.constructDb());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(localTransactions, localTransactions.userEmail);
          }
          if (from < 3) {
            await m.addColumn(localTransactions, localTransactions.clientUuid);
            await m.addColumn(
              localTransactions,
              localTransactions.paymentMethod,
            );
            await m.addColumn(
              localTransactions,
              localTransactions.creditCardUuid,
            );
            await m.addColumn(localTransactions, localTransactions.updatedAt);
            await m.addColumn(localTransactions, localTransactions.deletedAt);

            await m.addColumn(localBudgets, localBudgets.userEmail);
            await m.addColumn(localMetrics, localMetrics.userEmail);
            await m.addColumn(
              localAgentInsights,
              localAgentInsights.userEmail,
            );

            await m.createTable(localBills);
            await m.createTable(localCreditCards);
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

  /// Stream reativa de transações ativas (`deletedAt IS NULL`) filtradas por conta (`userEmail`) ordenadas por data
  Stream<List<LocalTransaction>> watchAllTransactions({String? userEmail}) {
    final query = select(localTransactions)
      ..where((t) => t.deletedAt.isNull());
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
    return (delete(localTransactions)..where((t) => t.id.equals(transactionId)))
        .go();
  }

  /// Atualização de status de sincronização com o backend
  Future<bool> markAsSynced(int transactionId) {
    return (update(localTransactions)..where((t) => t.id.equals(transactionId)))
        .write(const LocalTransactionsCompanion(isSynced: Value(true)))
        .then((rows) => rows > 0);
  }

  /// Gera um identificador universal UUID v4 compatível com RFC 4122 para `clientUuid`
  static String generateClientUuid() {
    Random random;
    try {
      random = Random.secure();
    } catch (_) {
      random = Random();
    }
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versão 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  /// Calcula a data de vencimento do mês seguinte com ajuste para dias 28/29/30/31
  static DateTime _calculateNextMonthDueDate(DateTime currentDueDate) {
    final nextYear = currentDueDate.month == 12
        ? currentDueDate.year + 1
        : currentDueDate.year;
    final nextMonth =
        currentDueDate.month == 12 ? 1 : currentDueDate.month + 1;
    final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final clampedDay = currentDueDate.day > lastDayOfNextMonth
        ? lastDayOfNextMonth
        : currentDueDate.day;
    return DateTime(
      nextYear,
      nextMonth,
      clampedDay,
      currentDueDate.hour,
      currentDueDate.minute,
      currentDueDate.second,
    );
  }

  /// Stream reativa de todos os boletos ativos (`deletedAt IS NULL`) filtrados por conta (`userEmail`) e ordenados por vencimento (T013)
  Stream<List<LocalBill>> watchAllBills({String? userEmail}) {
    final query = select(localBills)..where((b) => b.deletedAt.isNull());
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final normalized = userEmail.trim().toLowerCase();
      query.where((b) => b.userEmail.equals(normalized));
    }
    return (query
          ..orderBy([
            (b) => OrderingTerm.asc(b.dueDate),
            (b) => OrderingTerm.asc(b.id),
          ]))
        .watch();
  }

  /// Busca um boleto pelo ID local
  Future<LocalBill?> getBillById(int billId) {
    return (select(localBills)..where((b) => b.id.equals(billId)))
        .getSingleOrNull();
  }

  /// Inserção de novo boleto garantindo `clientUuid` e `updatedAt` (T013)
  Future<int> insertBill(LocalBillsCompanion entry) {
    final now = DateTime.now();
    final hasUuid =
        entry.clientUuid.present && entry.clientUuid.value.trim().isNotEmpty;
    final companion = entry.copyWith(
      clientUuid:
          hasUuid ? entry.clientUuid : Value(generateClientUuid()),
      updatedAt:
          entry.updatedAt.present ? entry.updatedAt : Value(now),
    );
    return into(localBills).insert(companion);
  }

  /// Atualização de boleto existente por ID marcando `isSynced = false` e `updatedAt = now` (T013)
  Future<int> updateBill(int billId, LocalBillsCompanion entry) {
    final now = DateTime.now();
    final companion = entry.copyWith(
      isSynced: entry.isSynced.present ? entry.isSynced : const Value(false),
      updatedAt: entry.updatedAt.present ? entry.updatedAt : Value(now),
    );
    return (update(localBills)..where((b) => b.id.equals(billId)))
        .write(companion);
  }

  /// Exclusão de boleto por ID (suporta soft delete por padrão para sincronização na nuvem) (T013)
  Future<int> deleteBillById(int billId, {bool softDelete = true}) {
    if (softDelete) {
      final now = DateTime.now();
      return (update(localBills)..where((b) => b.id.equals(billId))).write(
        LocalBillsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }
    return (delete(localBills)..where((b) => b.id.equals(billId))).go();
  }

  /// Marca um boleto como sincronizado com o backend
  Future<bool> markBillAsSynced(int billId) {
    return (update(localBills)..where((b) => b.id.equals(billId)))
        .write(const LocalBillsCompanion(isSynced: Value(true)))
        .then((rows) => rows > 0);
  }

  /// Dá baixa em um boleto de forma atômica (`payBillAndCreateTransaction`) (T013):
  /// 1. Marca o boleto como `'paid'` com `paidAt = now`;
  /// 2. Insere a despesa em `LocalTransactions` (`paymentMethod = 'Boleto'`) SOMENTE quando
  ///    `isCreditCardCharge == false`, evitando subtrair em duplicidade do saldo líquido (FR-011b);
  /// 3. Se `isRecurring == true`, agenda automaticamente o boleto pendente do mês seguinte.
  Future<PayBillResult> payBillAndCreateTransaction(
    int billId, {
    DateTime? paidAt,
  }) async {
    return transaction(() async {
      final bill = await getBillById(billId);
      if (bill == null || bill.deletedAt != null) {
        throw StateError('Boleto não encontrado para baixa (id: $billId).');
      }

      if (bill.status.toLowerCase() == 'paid') {
        return PayBillResult(
          paidBillId: bill.id,
          isCreditCardCharge: bill.isCreditCardCharge,
          createdTransactionId: bill.linkedTransactionId,
          createdTransactionUuid: bill.linkedTxUuid,
        );
      }

      final paymentTimestamp = paidAt ?? DateTime.now();
      int? createdTxId;
      String? createdTxUuid;

      // FR-011 / FR-011b: Apenas boletos convencionais (`!isCreditCardCharge`) geram saída
      // de caixa em `LocalTransactions`; itens embutidos na fatura do cartão não reduzem o saldo 2x.
      if (!bill.isCreditCardCharge) {
        createdTxUuid = generateClientUuid();
        createdTxId = await into(localTransactions).insert(
          LocalTransactionsCompanion.insert(
            clientUuid: Value(createdTxUuid),
            userEmail: Value(bill.userEmail),
            description: bill.description,
            amount: bill.amount,
            date: paymentTimestamp,
            type: 'expense',
            category: bill.category,
            paymentMethod: const Value('Boleto'),
            creditCardUuid: Value(bill.creditCardUuid),
            isSynced: const Value(false),
            updatedAt: Value(paymentTimestamp),
          ),
        );
      }

      await (update(localBills)..where((b) => b.id.equals(bill.id))).write(
        LocalBillsCompanion(
          status: const Value('paid'),
          paidAt: Value(paymentTimestamp),
          linkedTransactionId: Value(createdTxId),
          linkedTxUuid: Value(createdTxUuid),
          isSynced: const Value(false),
          updatedAt: Value(paymentTimestamp),
        ),
      );

      int? nextRecurringBillId;
      if (bill.isRecurring) {
        final nextDueDate = _calculateNextMonthDueDate(bill.dueDate);
        nextRecurringBillId = await into(localBills).insert(
          LocalBillsCompanion.insert(
            clientUuid: Value(generateClientUuid()),
            userEmail: Value(bill.userEmail),
            description: bill.description,
            amount: bill.amount,
            dueDate: nextDueDate,
            category: bill.category,
            barcode: Value(bill.barcode),
            isRecurring: const Value(true),
            isCreditCardCharge: Value(bill.isCreditCardCharge),
            creditCardUuid: Value(bill.creditCardUuid),
            status: const Value('pending'),
            isSynced: const Value(false),
            updatedAt: Value(paymentTimestamp),
          ),
        );
      }

      return PayBillResult(
        paidBillId: bill.id,
        isCreditCardCharge: bill.isCreditCardCharge,
        createdTransactionId: createdTxId,
        createdTransactionUuid: createdTxUuid,
        nextRecurringBillId: nextRecurringBillId,
      );
    });
  }

  /// Inserção de snapshot das 9 métricas financeiras
  Future<int> insertMetricSnapshot(LocalMetricsCompanion entry) {
    return into(localMetrics).insert(entry);
  }

  /// Stream do último snapshot de métricas gravado
  Stream<LocalMetric?> watchLatestMetric({String? userEmail}) {
    final query = select(localMetrics);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final normalized = userEmail.trim().toLowerCase();
      query.where((m) => m.userEmail.equals(normalized));
    }
    return (query
          ..orderBy([
            (m) => OrderingTerm.desc(m.calculatedAt),
            (m) => OrderingTerm.desc(m.id),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Inserção de novo insight do agente preditivo
  Future<int> insertAgentInsight(LocalAgentInsightsCompanion entry) {
    return into(localAgentInsights).insert(entry);
  }

  /// Stream do último insight do agente IA gravado
  Stream<LocalAgentInsight?> watchLatestAgentInsight({String? userEmail}) {
    final query = select(localAgentInsights);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final normalized = userEmail.trim().toLowerCase();
      query.where((i) => i.userEmail.equals(normalized));
    }
    return (query
          ..orderBy([
            (i) => OrderingTerm.desc(i.createdAt),
            (i) => OrderingTerm.desc(i.id),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Stream de todos os insights do agente IA ordenados por data
  Stream<List<LocalAgentInsight>> watchAllAgentInsights({String? userEmail}) {
    final query = select(localAgentInsights);
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final normalized = userEmail.trim().toLowerCase();
      query.where((i) => i.userEmail.equals(normalized));
    }
    return (query
          ..orderBy([
            (i) => OrderingTerm.desc(i.createdAt),
            (i) => OrderingTerm.desc(i.id),
          ]))
        .watch();
  }

  /// Garante a persistência inicial do seed padrão na tabela `LocalBudgets` caso esteja vazia
  Future<void> seedDefaultBudgetsIfEmpty({
    int? month,
    int? year,
    String? userEmail,
  }) async {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;
    final normalizedEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : 'marcos.pereira@gastosync.local';

    final existing = await (select(localBudgets)
          ..where(
            (b) =>
                b.month.equals(targetMonth) &
                b.year.equals(targetYear) &
                b.userEmail.equals(normalizedEmail),
          ))
        .get();

    if (existing.isNotEmpty) return;

    await batch((b) {
      for (final entry in defaultCategoryBudgets.entries) {
        b.insert(
          localBudgets,
          LocalBudgetsCompanion.insert(
            userEmail: Value(normalizedEmail),
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
  Stream<List<LocalBudget>> watchAllBudgets({
    int? month,
    int? year,
    String? userEmail,
  }) {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;
    final normalizedEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : null;

    final query = select(localBudgets)
      ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear));
    if (normalizedEmail != null) {
      query.where((b) => b.userEmail.equals(normalizedEmail));
    }
    query.orderBy([(b) => OrderingTerm.asc(b.id)]);

    return query.watch().map((persistedRows) {
      final byCategory = <String, LocalBudget>{};

      var syntheticId = -1;
      for (final entry in defaultCategoryBudgets.entries) {
        byCategory[entry.key.toLowerCase()] = LocalBudget(
          id: syntheticId--,
          userEmail: normalizedEmail ?? 'marcos.pereira@gastosync.local',
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
  Stream<Set<String>> watchDeletedBudgetCategories({
    int? month,
    int? year,
    String? userEmail,
  }) {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final query = select(localBudgets)
      ..where((b) => b.month.equals(targetMonth) & b.year.equals(targetYear));
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      query.where((b) => b.userEmail.equals(userEmail.trim().toLowerCase()));
    }

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
    String? userEmail,
  }) async {
    final normalizedCategory = category.trim();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;
    final normalizedEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : 'marcos.pereira@gastosync.local';

    final existingRows = await (select(localBudgets)
          ..where(
            (b) =>
                b.month.equals(targetMonth) &
                b.year.equals(targetYear) &
                b.userEmail.equals(normalizedEmail),
          ))
        .get();

    final match = existingRows
        .where(
          (b) =>
              b.category.trim().toLowerCase() ==
              normalizedCategory.toLowerCase(),
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
        userEmail: Value(normalizedEmail),
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
    String? userEmail,
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
    final normalizedEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : 'marcos.pereira@gastosync.local';

    final existingRows = await (select(localBudgets)
          ..where(
            (b) =>
                b.month.equals(targetMonth) &
                b.year.equals(targetYear) &
                b.userEmail.equals(normalizedEmail),
          ))
        .get();

    final alreadyExists = existingRows.any(
      (b) => b.category.trim().toLowerCase() == normalized.toLowerCase(),
    );

    if (!alreadyExists) {
      await into(localBudgets).insert(
        LocalBudgetsCompanion.insert(
          userEmail: Value(normalizedEmail),
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
    String? userEmail,
  }) async {
    final normalizedCategory = category.trim();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;
    final normalizedEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : 'marcos.pereira@gastosync.local';

    final existingRows = await (select(localBudgets)
          ..where(
            (b) =>
                b.month.equals(targetMonth) &
                b.year.equals(targetYear) &
                b.userEmail.equals(normalizedEmail),
          ))
        .get();

    final match = existingRows
        .where(
          (b) =>
              b.category.trim().toLowerCase() ==
              normalizedCategory.toLowerCase(),
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
        userEmail: Value(normalizedEmail),
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

  Future<void> clearAuthSession() async {
    await initCustomAuthTables();
    await customStatement('DELETE FROM local_auth_session;');
  }

  Future<void> saveAuthSession({
    required String? currentEmail,
    required bool isAuthenticated,
    String? jwtToken,
  }) async {
    await initCustomAuthTables();
    await customStatement(
      'INSERT OR REPLACE INTO local_auth_session (id, current_email, is_authenticated, jwt_token) VALUES (1, ?, ?, ?);',
      [currentEmail, 0, null],
    );
  }

  Future<Map<String, dynamic>?> getPersistedAuthSession() async {
    return null;
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
