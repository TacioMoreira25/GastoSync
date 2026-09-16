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

  test('Deve inserir e recuperar transação com stream reativa', () async {
    final entry = LocalTransactionsCompanion(
      description: const drift.Value('Salário Mensal'),
      amount: const drift.Value(15000.0),
      date: drift.Value(DateTime.now()),
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
  });
}
