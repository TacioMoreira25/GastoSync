import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/features/transactions/data/services/cloud_sync_service.dart';

class _MockSyncHttpClientAdapter implements HttpClientAdapter {
  _MockSyncHttpClientAdapter(this._onFetch);

  final Map<String, dynamic> Function(RequestOptions options) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = _onFetch(options);
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CloudSyncService.pullFromCloud — Reconciliação de exclusões entre dispositivos', () {
    late AppDatabase db;
    const userEmail = 'usuario@gastosync.local';
    const jwt = 'fake-jwt-token';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    CloudSyncService buildService(Map<String, dynamic> pullResponse) {
      final dio = Dio(BaseOptions(baseUrl: 'https://mock.gastosync.local'));
      dio.httpClientAdapter = _MockSyncHttpClientAdapter((_) => pullResponse);
      return CloudSyncService(database: db, dio: dio);
    }

    test(
      'remove transações locais já sincronizadas quando a nuvem retorna lista vazia (excluídas na Web)',
      () async {
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('11111111-1111-4111-8111-111111111111'),
            userEmail: const drift.Value(userEmail),
            description: 'Almoço',
            amount: 35.0,
            date: DateTime(2026, 11, 10),
            type: 'expense',
            category: 'Alimentação',
            isSynced: const drift.Value(true),
          ),
        );
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('22222222-2222-4222-8222-222222222222'),
            userEmail: const drift.Value(userEmail),
            description: 'Uber',
            amount: 22.5,
            date: DateTime(2026, 11, 11),
            type: 'expense',
            category: 'Transporte',
            isSynced: const drift.Value(true),
          ),
        );

        final service = buildService({
          'transactions': <Map<String, dynamic>>[],
          'bills': <Map<String, dynamic>>[],
          'budgets': <Map<String, dynamic>>[],
          'credit_cards': <Map<String, dynamic>>[],
        });

        final changes = await service.pullFromCloud(
          jwtToken: jwt,
          userEmail: userEmail,
        );

        expect(changes, equals(2));
        final remaining = await db.watchAllTransactions(userEmail: userEmail).first;
        expect(remaining, isEmpty);
      },
    );

    test(
      'preserva transações offline não sincronizadas (isSynced=false) mesmo quando a nuvem retorna lista vazia',
      () async {
        // Transação já sincronizada anteriormente (deve ser removida)
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('11111111-1111-4111-8111-111111111111'),
            userEmail: const drift.Value(userEmail),
            description: 'Apagada na Web',
            amount: 50.0,
            date: DateTime(2026, 11, 10),
            type: 'expense',
            category: 'Outros',
            isSynced: const drift.Value(true),
          ),
        );
        // Transação criada offline no celular (NÃO deve ser removida)
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('33333333-3333-4333-8333-333333333333'),
            userEmail: const drift.Value(userEmail),
            description: 'Café offline no celular',
            amount: 12.0,
            date: DateTime(2026, 11, 12),
            type: 'expense',
            category: 'Alimentação',
            isSynced: const drift.Value(false),
          ),
        );

        final service = buildService({
          'transactions': <Map<String, dynamic>>[],
          'bills': <Map<String, dynamic>>[],
          'budgets': <Map<String, dynamic>>[],
          'credit_cards': <Map<String, dynamic>>[],
        });

        final changes = await service.pullFromCloud(
          jwtToken: jwt,
          userEmail: userEmail,
        );

        expect(changes, equals(1));
        final remaining = await db.watchAllTransactions(userEmail: userEmail).first;
        expect(remaining.length, equals(1));
        expect(remaining.first.description, equals('Café offline no celular'));
        expect(remaining.first.isSynced, isFalse);
      },
    );

    test(
      'mantém transações ainda presentes na nuvem e remove apenas as excluídas remotamente',
      () async {
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
            userEmail: const drift.Value(userEmail),
            description: 'Mantida na nuvem',
            amount: 100.0,
            date: DateTime(2026, 11, 10),
            type: 'expense',
            category: 'Moradia',
            isSynced: const drift.Value(true),
          ),
        );
        await db.insertTransaction(
          LocalTransactionsCompanion.insert(
            clientUuid: const drift.Value('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
            userEmail: const drift.Value(userEmail),
            description: 'Excluída na nuvem',
            amount: 40.0,
            date: DateTime(2026, 11, 11),
            type: 'expense',
            category: 'Lazer',
            isSynced: const drift.Value(true),
          ),
        );

        final service = buildService({
          'transactions': [
            {
              'client_uuid': 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
              'description': 'Mantida na nuvem',
              'amount': 100.0,
              'tx_date': DateTime(2026, 11, 10).toUtc().toIso8601String(),
              'tx_type': 'expense',
              'category': 'Moradia',
              'payment_method': 'PIX',
            },
          ],
          'bills': <Map<String, dynamic>>[],
          'budgets': <Map<String, dynamic>>[],
          'credit_cards': <Map<String, dynamic>>[],
        });

        final changes = await service.pullFromCloud(
          jwtToken: jwt,
          userEmail: userEmail,
        );

        expect(changes, equals(1));
        final remaining = await db.watchAllTransactions(userEmail: userEmail).first;
        expect(remaining.length, equals(1));
        expect(remaining.first.description, equals('Mantida na nuvem'));
      },
    );

    test(
      'remove boletos sincronizados excluídos na nuvem e preserva boletos offline não sincronizados',
      () async {
        await db.insertBill(
          LocalBillsCompanion.insert(
            clientUuid: const drift.Value('44444444-4444-4444-8444-444444444444'),
            userEmail: const drift.Value(userEmail),
            description: 'Boleto apagado na Web',
            amount: 199.90,
            dueDate: DateTime(2026, 11, 20),
            category: 'Moradia',
            isSynced: const drift.Value(true),
          ),
        );
        await db.insertBill(
          LocalBillsCompanion.insert(
            clientUuid: const drift.Value('55555555-5555-4555-8555-555555555555'),
            userEmail: const drift.Value(userEmail),
            description: 'Boleto criado offline',
            amount: 89.90,
            dueDate: DateTime(2026, 11, 25),
            category: 'Serviços',
            isSynced: const drift.Value(false),
          ),
        );

        final service = buildService({
          'transactions': <Map<String, dynamic>>[],
          'bills': <Map<String, dynamic>>[],
          'budgets': <Map<String, dynamic>>[],
          'credit_cards': <Map<String, dynamic>>[],
        });

        final changes = await service.pullFromCloud(
          jwtToken: jwt,
          userEmail: userEmail,
        );

        expect(changes, equals(1));
        final remainingBills = await db.watchAllBills(userEmail: userEmail).first;
        expect(remainingBills.length, equals(1));
        expect(remainingBills.first.description, equals('Boleto criado offline'));
      },
    );
  });
}
