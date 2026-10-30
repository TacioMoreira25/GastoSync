import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/transaction.dart';

@immutable
class CloudSyncResult {
  const CloudSyncResult({
    required this.syncedCount,
    required this.isCloudSynced,
    required this.message,
  });

  final int syncedCount;
  final bool isCloudSynced;
  final String message;
}

/// Serviço de sincronização em nuvem (Push/Pull) com o backend Go (`gastosync_api`)
/// Operando em modo Offline-First no Mobile e modo autenticado Online/Local na Web (T053).
class CloudSyncService {
  CloudSyncService({
    required AppDatabase database,
    Dio? dio,
  })  : _db = database,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.coreApiBaseUrl,
                connectTimeout: const Duration(milliseconds: 3500),
                receiveTimeout: const Duration(milliseconds: 5000),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final AppDatabase _db;
  final Dio _dio;

  /// Envia transações pendentes e orçamentos locais para `POST /api/v1/sync/push`
  /// e atualiza o status `isSynced = true` no banco SQLite local.
  Future<CloudSyncResult> pushPendingTransactions({
    required List<Transaction> pendingTransactions,
    required String? jwtToken,
    List<LocalBudget> budgets = const <LocalBudget>[],
  }) async {
    var cloudSuccess = false;

    if (jwtToken != null &&
        jwtToken.isNotEmpty &&
        (pendingTransactions.isNotEmpty || budgets.isNotEmpty)) {
      try {
        final txPayload = pendingTransactions
            .map(
              (tx) => <String, dynamic>{
                'local_id': tx.id ?? 0,
                'description': tx.description,
                'amount': tx.amount,
                'tx_date': tx.date.toUtc().toIso8601String(),
                'date': tx.date.toUtc().toIso8601String(),
                'tx_type': tx.type.name,
                'type': tx.type.name,
                'category': tx.category,
                'payment_method': 'PIX',
              },
            )
            .toList();

        final budgetPayload = budgets
            .where((b) => b.limitAmount > 0)
            .map(
              (b) => <String, dynamic>{
                'category': b.category,
                'limit_amount': b.limitAmount,
                'month': b.month,
                'year': b.year,
              },
            )
            .toList();

        final response = await _dio.post<Map<String, dynamic>>(
          ApiConstants.syncPushEndpoint,
          data: <String, dynamic>{
            'transactions': txPayload,
            'budgets': budgetPayload,
          },
          options: Options(
            headers: <String, dynamic>{
              'Authorization': 'Bearer $jwtToken',
            },
          ),
        );

        cloudSuccess =
            response.statusCode != null && response.statusCode! < 300;
      } catch (_) {
        cloudSuccess = false;
      }
    }

    var markedLocally = 0;
    for (final tx in pendingTransactions) {
      if (tx.id != null) {
        final updated = await _db.markAsSynced(tx.id!);
        if (updated) markedLocally++;
      }
    }

    if (markedLocally == 0) {
      return CloudSyncResult(
        syncedCount: 0,
        isCloudSynced: cloudSuccess,
        message: 'Banco local já está 100% sincronizado.',
      );
    }

    return CloudSyncResult(
      syncedCount: markedLocally,
      isCloudSynced: cloudSuccess,
      message:
          'Sincronização concluída: $markedLocally transação(ões) sincronizada(s).',
    );
  }

  /// Baixa transações e orçamentos remotos da nuvem (`GET /api/v1/sync/pull`)
  /// para a conta autenticada (`userEmail`) e hidrata o banco SQLite local.
  Future<int> pullFromCloud({
    required String? jwtToken,
    required String userEmail,
  }) async {
    if (jwtToken == null || jwtToken.isEmpty || userEmail.trim().isEmpty) {
      return 0;
    }

    final normalizedEmail = userEmail.trim().toLowerCase();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.syncPullEndpoint,
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $jwtToken',
          },
        ),
      );

      final data = response.data;
      if (data == null) return 0;

      final existingLocal = await _db
          .watchAllTransactions(userEmail: normalizedEmail)
          .first;

      var importedCount = 0;
      final remoteTransactions = data['transactions'];
      if (remoteTransactions is List) {
        for (final item in remoteTransactions) {
          if (item is! Map) continue;
          final desc = (item['description'] as String? ?? '').trim();
          final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
          final dateStr =
              (item['tx_date'] as String?) ?? (item['date'] as String?);
          final parsedDate = dateStr != null
              ? (DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now())
              : DateTime.now();
          final type =
              ((item['tx_type'] as String?) ?? (item['type'] as String?) ?? 'expense')
                  .trim();
          final category = (item['category'] as String? ?? 'Outros').trim();

          if (desc.isEmpty || amount <= 0) continue;

          final alreadyExists = existingLocal.any(
            (local) =>
                local.description == desc &&
                (local.amount - amount).abs() < 0.01 &&
                local.type == type &&
                local.category == category &&
                local.date.year == parsedDate.year &&
                local.date.month == parsedDate.month &&
                local.date.day == parsedDate.day,
          );

          if (!alreadyExists) {
            await _db.insertTransaction(
              LocalTransactionsCompanion(
                userEmail: Value(normalizedEmail),
                description: Value(desc),
                amount: Value(amount),
                date: Value(parsedDate),
                type: Value(type),
                category: Value(category),
                isSynced: const Value(true),
              ),
            );
            importedCount++;
          }
        }
      }

      final remoteBudgets = data['budgets'];
      if (remoteBudgets is List) {
        for (final item in remoteBudgets) {
          if (item is! Map) continue;
          final category = (item['category'] as String? ?? '').trim();
          final limitAmount = (item['limit_amount'] as num?)?.toDouble() ?? 0.0;
          final month = (item['month'] as num?)?.toInt();
          final year = (item['year'] as num?)?.toInt();
          if (category.isNotEmpty && limitAmount > 0) {
            await _db.upsertBudget(
              category: category,
              limitAmount: limitAmount,
              month: month,
              year: year,
            );
          }
        }
      }

      return importedCount;
    } catch (_) {
      return 0;
    }
  }
}

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CloudSyncService(database: db);
});
