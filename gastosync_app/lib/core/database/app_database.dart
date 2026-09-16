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

@DriftDatabase(tables: [LocalTransactions, LocalBudgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Stream reativa de todas as transações ordenadas por data
  Stream<List<LocalTransaction>> watchAllTransactions() {
    return (select(localTransactions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Inserção de nova transação
  Future<int> insertTransaction(LocalTransactionsCompanion entry) {
    return into(localTransactions).insert(entry);
  }

  /// Atualização de status de sincronização com o backend
  Future<bool> markAsSynced(int transactionId) {
    return (update(localTransactions)..where((t) => t.id.equals(transactionId)))
        .write(const LocalTransactionsCompanion(isSynced: Value(true)))
        .then((rows) => rows > 0);
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
