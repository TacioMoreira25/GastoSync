import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/bill.dart';
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
/// Operando em modo Offline-First no Mobile e modo autenticado Online/Local na Web (T053 / T026).
class CloudSyncService {
  CloudSyncService({
    required AppDatabase database,
    Dio? dio,
  })  : _db = database,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.coreApiBaseUrl,
                connectTimeout: ApiConstants.coreApiTimeout,
                receiveTimeout: ApiConstants.coreApiTimeout,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final AppDatabase _db;
  final Dio _dio;

  static DateTime _parseValidCloudDate(
    Object? primary,
    Object? secondary, {
    DateTime? fallback,
  }) {
    for (final candidate in [primary, secondary]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(candidate.trim());
        if (parsed != null && parsed.year >= 2000) {
          return parsed.toLocal();
        }
      }
    }
    if (fallback != null && fallback.year >= 2000) {
      return fallback;
    }
    return DateTime.now();
  }

  /// Envia transações pendentes (incluindo exclusões lógicas `deleted_at`),
  /// boletos pendentes (`bills`) e orçamentos locais para `POST /api/v1/sync/push`
  /// e atualiza o status `isSynced = true` no banco SQLite local (T026).
  Future<CloudSyncResult> pushPendingTransactions({
    List<Transaction> pendingTransactions = const <Transaction>[],
    required String? jwtToken,
    List<Bill> pendingBills = const <Bill>[],
    List<LocalBudget> budgets = const <LocalBudget>[],
    String? userEmail,
  }) async {
    // Coleta também registros pendentes no SQLite (incluindo soft-deletes com deletedAt != null)
    final dbPendingTxRows = await _db.getPendingSyncTransactions(
      userEmail: userEmail,
    );
    final dbPendingBillRows = await _db.getPendingSyncBills(
      userEmail: userEmail,
    );

    final mergedTransactionsById = <String, Transaction>{};
    for (final tx in pendingTransactions) {
      final key = tx.id != null
          ? 'id:${tx.id}'
          : (tx.clientUuid.isNotEmpty
              ? 'uuid:${tx.clientUuid}'
              : 'desc:${tx.description}:${tx.date.millisecondsSinceEpoch}');
      mergedTransactionsById[key] = tx;
    }
    for (final row in dbPendingTxRows) {
      final tx = Transaction.fromLocal(row);
      final key = tx.id != null ? 'id:${tx.id}' : 'uuid:${tx.clientUuid}';
      mergedTransactionsById.putIfAbsent(key, () => tx);
    }

    final mergedBillsById = <String, Bill>{};
    for (final bill in pendingBills) {
      final key = bill.id != null
          ? 'id:${bill.id}'
          : (bill.clientUuid.isNotEmpty
              ? 'uuid:${bill.clientUuid}'
              : 'desc:${bill.description}:${bill.dueDate.millisecondsSinceEpoch}');
      mergedBillsById[key] = bill;
    }
    for (final row in dbPendingBillRows) {
      final bill = Bill.fromLocal(row);
      final key = bill.id != null ? 'id:${bill.id}' : 'uuid:${bill.clientUuid}';
      mergedBillsById.putIfAbsent(key, () => bill);
    }

    final allPendingTransactions = mergedTransactionsById.values.toList();
    final allPendingBills = mergedBillsById.values.toList();
    final allPendingCreditCards = await _db.getPendingSyncCreditCards(
      userEmail: userEmail,
    );

    var cloudSuccess = false;
    String? serverError;

    if (jwtToken != null &&
        jwtToken.isNotEmpty &&
        (allPendingTransactions.isNotEmpty ||
            allPendingBills.isNotEmpty ||
            allPendingCreditCards.isNotEmpty ||
            budgets.isNotEmpty)) {
      try {
        final txPayload = allPendingTransactions.map((tx) {
          final resolvedUuid = (tx.clientUuid.trim().isNotEmpty &&
                  tx.clientUuid.trim() !=
                      '00000000-0000-4000-8000-000000000001')
              ? tx.clientUuid.trim()
              : AppDatabase.generateClientUuid();
          final resolvedMethod = tx.paymentMethod.trim().isNotEmpty
              ? tx.paymentMethod.trim()
              : 'PIX';
          final map = <String, dynamic>{
            'client_uuid': resolvedUuid,
            'description': tx.description,
            'amount': tx.amount,
            'tx_date': tx.date.toUtc().toIso8601String(),
            'date': tx.date.toUtc().toIso8601String(),
            'tx_type': tx.type.name,
            'type': tx.type.name,
            'category': tx.category,
            'payment_method': resolvedMethod,
          };
          if (tx.creditCardUuid != null &&
              tx.creditCardUuid!.trim().isNotEmpty) {
            map['credit_card_uuid'] = tx.creditCardUuid!.trim();
          }
          if (tx.updatedAt != null) {
            map['updated_at'] = tx.updatedAt!.toUtc().toIso8601String();
          }
          if (tx.deletedAt != null) {
            map['deleted_at'] = tx.deletedAt!.toUtc().toIso8601String();
          }
          return map;
        }).toList();

        final billsPayload = allPendingBills.map((bill) {
          final resolvedUuid = (bill.clientUuid.trim().isNotEmpty &&
                  bill.clientUuid.trim() !=
                      '00000000-0000-4000-8000-000000000001')
              ? bill.clientUuid.trim()
              : AppDatabase.generateClientUuid();
          final map = <String, dynamic>{
            'client_uuid': resolvedUuid,
            'description': bill.description,
            'amount': bill.amount,
            'due_date': bill.dueDate.toUtc().toIso8601String(),
            'category': bill.category,
            'barcode': bill.barcode,
            'is_recurring': bill.isRecurring,
            'is_credit_card_charge': bill.isCreditCardCharge,
            'status': bill.status.value,
          };
          if (bill.creditCardUuid != null &&
              bill.creditCardUuid!.trim().isNotEmpty) {
            map['credit_card_uuid'] = bill.creditCardUuid!.trim();
          }
          if (bill.paidAt != null) {
            map['paid_at'] = bill.paidAt!.toUtc().toIso8601String();
          }
          if (bill.linkedTxUuid != null &&
              bill.linkedTxUuid!.trim().isNotEmpty) {
            map['linked_tx_uuid'] = bill.linkedTxUuid!.trim();
          }
          if (bill.updatedAt != null) {
            map['updated_at'] = bill.updatedAt!.toUtc().toIso8601String();
          }
          if (bill.deletedAt != null) {
            map['deleted_at'] = bill.deletedAt!.toUtc().toIso8601String();
          }
          return map;
        }).toList();

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
            'bills': billsPayload,
            'credit_cards': _serializeCreditCardsPayload(allPendingCreditCards),
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
      } on DioException catch (e) {
        cloudSuccess = false;
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          serverError = (data['message'] ?? data['error'])?.toString();
        }
      } catch (_) {
        cloudSuccess = false;
      }
    }

    final isLocalOnlySession = jwtToken == null || jwtToken.trim().isEmpty;
    var markedLocally = 0;

    if (cloudSuccess || isLocalOnlySession) {
      for (final tx in allPendingTransactions) {
        if (tx.id != null) {
          final updated = await _db.markAsSynced(tx.id!);
          if (updated) markedLocally++;
        }
      }

      for (final bill in allPendingBills) {
        if (bill.id != null) {
          final updated = await _db.markBillAsSynced(bill.id!);
          if (updated) markedLocally++;
        }
      }

      for (final card in allPendingCreditCards) {
        final updated = await _db.markCreditCardAsSynced(card.id);
        if (updated) markedLocally++;
      }
    }

    final hasPendingWork = allPendingTransactions.isNotEmpty ||
        allPendingBills.isNotEmpty ||
        allPendingCreditCards.isNotEmpty;

    if (markedLocally == 0) {
      return CloudSyncResult(
        syncedCount: 0,
        isCloudSynced: cloudSuccess,
        message: cloudSuccess
            ? 'Sincronização com a nuvem concluída! Todos os dados estão atualizados.'
            : (hasPendingWork
                ? (serverError ??
                    'Sem conexão com a nuvem no momento. Seus dados continuam salvos localmente.')
                : (serverError ?? 'Banco local já está 100% sincronizado.')),
      );
    }

    return CloudSyncResult(
      syncedCount: markedLocally,
      isCloudSynced: cloudSuccess,
      message: cloudSuccess
          ? 'Sincronização em nuvem concluída: $markedLocally registro(s) enviado(s).'
          : 'Salvo no banco local ($markedLocally registro(s)). Nuvem indisponível no momento.',
    );
  }

  /// Baixa transações, boletos e orçamentos remotos da nuvem (`GET /api/v1/sync/pull`)
  /// para a conta autenticada (`userEmail`) e hidrata o banco SQLite local (T026).
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

      // Consulta TODAS as transações locais (incluindo exclusões lógicas `deletedAt != null`)
      // para garantir que transações apagadas pelo usuário NUNCA sejam restauradas da nuvem.
      final existingLocal = await _db.getAllTransactionsIncludingDeleted(
        userEmail: normalizedEmail,
      );

      var importedCount = 0;
      var hasUnpushedTombstones = false;
      final remoteTransactions = data['transactions'];
      if (data.containsKey('transactions') && remoteTransactions is List) {
        final activeRemoteTxUuids = <String>{};
        final matchedLocalTxIds = <int>{};

        for (final item in remoteTransactions) {
          if (item is! Map) continue;
          if (item['deleted_at'] != null) continue;

          final clientUuid = (item['client_uuid'] as String? ?? '').trim();
          final normalizedUuid = clientUuid.toLowerCase();
          final desc = (item['description'] as String? ?? '').trim();
          final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
          final parsedDate = _parseValidCloudDate(
            item['date'],
            item['tx_date'],
          );
          final type = ((item['tx_type'] as String?) ??
                  (item['type'] as String?) ??
                  'expense')
              .trim();
          final category = (item['category'] as String? ?? 'Outros').trim();
          final rawPaymentMethod =
              (item['payment_method'] as String? ?? 'PIX').trim();
          final paymentMethod =
              rawPaymentMethod.isEmpty ? 'PIX' : rawPaymentMethod;
          final creditCardUuid =
              (item['credit_card_uuid'] as String?)?.trim();
          final updatedAtStr = item['updated_at'] as String?;
          final parsedUpdatedAt = updatedAtStr != null
              ? DateTime.tryParse(updatedAtStr)?.toLocal()
              : null;

          if (desc.isEmpty || amount <= 0) continue;
          if (normalizedUuid.isNotEmpty) {
            activeRemoteTxUuids.add(normalizedUuid);
          }

          LocalTransaction? matchedByUuid;
          if (normalizedUuid.isNotEmpty) {
            for (final local in existingLocal) {
              if (local.clientUuid.trim().toLowerCase() == normalizedUuid) {
                matchedByUuid = local;
                break;
              }
            }
          }

          if (matchedByUuid != null) {
            // Se foi apagada localmente (tombstone), NÃO restaura e agenda envio da exclusão
            if (matchedByUuid.deletedAt != null) {
              if (matchedByUuid.isSynced) {
                await _db.updateTransaction(
                  matchedByUuid.id,
                  const LocalTransactionsCompanion(isSynced: Value(false)),
                );
              }
              hasUnpushedTombstones = true;
              continue;
            }

            matchedLocalTxIds.add(matchedByUuid.id);
            if (matchedByUuid.isSynced) {
              await _db.updateTransaction(
                matchedByUuid.id,
                LocalTransactionsCompanion(
                  clientUuid: Value(clientUuid),
                  userEmail: Value(normalizedEmail),
                  description: Value(desc),
                  amount: Value(amount),
                  date: Value(parsedDate),
                  type: Value(type),
                  category: Value(category),
                  paymentMethod: Value(paymentMethod),
                  creditCardUuid: Value(creditCardUuid),
                  isSynced: const Value(true),
                  updatedAt: Value(parsedUpdatedAt ?? DateTime.now()),
                ),
              );
            }
            continue;
          }

          LocalTransaction? matchedByContent;
          for (final local in existingLocal) {
            final sameAttributes = local.description == desc &&
                (local.amount - amount).abs() < 0.01 &&
                local.type == type &&
                local.category == category &&
                local.date.difference(parsedDate).inHours.abs() <= 36;
            if (sameAttributes) {
              matchedByContent = local;
              if (local.deletedAt != null) break;
            }
          }

          if (matchedByContent != null) {
            // Se já existia e foi excluída localmente, garante que o UUID remoto também receba tombstone na nuvem e não re-insere
            if (matchedByContent.deletedAt != null) {
              if (clientUuid.isNotEmpty) {
                if (matchedByContent.clientUuid.trim().toLowerCase() ==
                    normalizedUuid) {
                  await _db.updateTransaction(
                    matchedByContent.id,
                    const LocalTransactionsCompanion(isSynced: Value(false)),
                  );
                } else {
                  await _db.insertTransaction(
                    LocalTransactionsCompanion(
                      clientUuid: Value(clientUuid),
                      userEmail: Value(normalizedEmail),
                      description: Value(desc),
                      amount: Value(amount),
                      date: Value(parsedDate),
                      type: Value(type),
                      category: Value(category),
                      paymentMethod: Value(paymentMethod),
                      creditCardUuid: Value(creditCardUuid),
                      isSynced: const Value(false),
                      updatedAt: Value(DateTime.now()),
                      deletedAt: Value(matchedByContent.deletedAt),
                    ),
                  );
                }
              }
              hasUnpushedTombstones = true;
            } else {
              matchedLocalTxIds.add(matchedByContent.id);
              if (clientUuid.isNotEmpty &&
                  matchedByContent.clientUuid != clientUuid) {
                await _db.updateTransaction(
                  matchedByContent.id,
                  LocalTransactionsCompanion(
                    clientUuid: Value(clientUuid),
                  ),
                );
              }
            }
            continue;
          }

          await _db.insertTransaction(
            LocalTransactionsCompanion(
              clientUuid: Value(
                clientUuid.isNotEmpty
                    ? clientUuid
                    : AppDatabase.generateClientUuid(),
              ),
              userEmail: Value(normalizedEmail),
              description: Value(desc),
              amount: Value(amount),
              date: Value(parsedDate),
              type: Value(type),
              category: Value(category),
              paymentMethod: Value(paymentMethod),
              creditCardUuid: Value(creditCardUuid),
              isSynced: const Value(true),
              updatedAt: Value(parsedUpdatedAt ?? DateTime.now()),
            ),
          );
          importedCount++;
        }

        // Remove localmente apenas transações já sincronizadas que foram apagadas em outro dispositivo
        // Preserva intactas transações criadas/alteradas offline (`isSynced == false`).
        for (final localTx in existingLocal) {
          if (localTx.deletedAt != null || !localTx.isSynced) continue;
          if (matchedLocalTxIds.contains(localTx.id)) continue;
          final uuid = localTx.clientUuid.trim().toLowerCase();
          if (uuid.isEmpty || !activeRemoteTxUuids.contains(uuid)) {
            await _db.deleteTransactionById(localTx.id, softDelete: false);
            importedCount++;
          }
        }
      }

      // Hidratação de Boletos (`LocalBills`) respeitando exclusões lógicas locais (T026)
      final existingBills = await _db.getAllBillsIncludingDeleted(
        userEmail: normalizedEmail,
      );
      final remoteBills = data['bills'];
      if (data.containsKey('bills') && remoteBills is List) {
        final activeRemoteBillUuids = <String>{};
        final matchedLocalBillIds = <int>{};

        for (final item in remoteBills) {
          if (item is! Map) continue;
          if (item['deleted_at'] != null) continue;

          final clientUuid = (item['client_uuid'] as String? ?? '').trim();
          final normalizedUuid = clientUuid.toLowerCase();
          final desc = (item['description'] as String? ?? '').trim();
          final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
          final dueDateStr = item['due_date'] as String?;
          final parsedDueDate = dueDateStr != null
              ? (DateTime.tryParse(dueDateStr)?.toLocal() ?? DateTime.now())
              : DateTime.now();
          final category = (item['category'] as String? ?? 'Outros').trim();
          final barcode = (item['barcode'] as String? ?? '').trim();
          final isRecurring = (item['is_recurring'] as bool?) ?? false;
          final isCreditCardCharge =
              (item['is_credit_card_charge'] as bool?) ?? false;
          final creditCardUuid =
              (item['credit_card_uuid'] as String?)?.trim();
          final status = (item['status'] as String? ?? 'pending').trim();
          final paidAtStr = item['paid_at'] as String?;
          final parsedPaidAt = paidAtStr != null
              ? DateTime.tryParse(paidAtStr)?.toLocal()
              : null;
          final linkedTxUuid = (item['linked_tx_uuid'] as String?)?.trim();
          final updatedAtStr = item['updated_at'] as String?;
          final parsedUpdatedAt = updatedAtStr != null
              ? DateTime.tryParse(updatedAtStr)?.toLocal()
              : null;

          if (desc.isEmpty || amount <= 0) continue;
          if (normalizedUuid.isNotEmpty) {
            activeRemoteBillUuids.add(normalizedUuid);
          }

          LocalBill? matchedBillByUuid;
          if (normalizedUuid.isNotEmpty) {
            for (final local in existingBills) {
              if (local.clientUuid.trim().toLowerCase() == normalizedUuid) {
                matchedBillByUuid = local;
                break;
              }
            }
          }

          if (matchedBillByUuid != null) {
            if (matchedBillByUuid.deletedAt != null) {
              if (matchedBillByUuid.isSynced) {
                await _db.updateBill(
                  matchedBillByUuid.id,
                  const LocalBillsCompanion(isSynced: Value(false)),
                );
              }
              hasUnpushedTombstones = true;
              continue;
            }
            matchedLocalBillIds.add(matchedBillByUuid.id);
            if (matchedBillByUuid.isSynced) {
              await _db.updateBill(
                matchedBillByUuid.id,
                LocalBillsCompanion(
                  clientUuid: Value(clientUuid),
                  userEmail: Value(normalizedEmail),
                  description: Value(desc),
                  amount: Value(amount),
                  dueDate: Value(parsedDueDate),
                  category: Value(category),
                  barcode: Value(barcode),
                  isRecurring: Value(isRecurring),
                  isCreditCardCharge: Value(isCreditCardCharge),
                  creditCardUuid: Value(creditCardUuid),
                  status: Value(status),
                  paidAt: Value(parsedPaidAt),
                  linkedTxUuid: Value(linkedTxUuid),
                  isSynced: const Value(true),
                  updatedAt: Value(parsedUpdatedAt ?? DateTime.now()),
                ),
              );
            }
            continue;
          }

          LocalBill? matchedBillByContent;
          for (final local in existingBills) {
            final sameBill = local.description == desc &&
                (local.amount - amount).abs() < 0.01 &&
                local.category == category &&
                local.dueDate.year == parsedDueDate.year &&
                local.dueDate.month == parsedDueDate.month &&
                local.dueDate.day == parsedDueDate.day;
            if (sameBill) {
              matchedBillByContent = local;
              if (local.deletedAt != null) break;
            }
          }

          if (matchedBillByContent != null) {
            if (matchedBillByContent.deletedAt != null) {
              if (clientUuid.isNotEmpty) {
                await _db.updateBill(
                  matchedBillByContent.id,
                  LocalBillsCompanion(
                    clientUuid: Value(clientUuid),
                    isSynced: const Value(false),
                  ),
                );
              }
              hasUnpushedTombstones = true;
            } else {
              matchedLocalBillIds.add(matchedBillByContent.id);
            }
            continue;
          }

          await _db.insertBill(
            LocalBillsCompanion(
              clientUuid: Value(
                clientUuid.isNotEmpty
                    ? clientUuid
                    : AppDatabase.generateClientUuid(),
              ),
              userEmail: Value(normalizedEmail),
              description: Value(desc),
              amount: Value(amount),
              dueDate: Value(parsedDueDate),
              category: Value(category),
              barcode: Value(barcode),
              isRecurring: Value(isRecurring),
              isCreditCardCharge: Value(isCreditCardCharge),
              creditCardUuid: Value(creditCardUuid),
              status: Value(status),
              paidAt: Value(parsedPaidAt),
              linkedTxUuid: Value(linkedTxUuid),
              isSynced: const Value(true),
              updatedAt: Value(parsedUpdatedAt ?? DateTime.now()),
            ),
          );
          importedCount++;
        }

        // Remove localmente apenas boletos já sincronizados que foram apagados em outro dispositivo
        // Preserva intactos boletos criados/alterados offline (`isSynced == false`).
        for (final localBill in existingBills) {
          if (localBill.deletedAt != null || !localBill.isSynced) continue;
          if (matchedLocalBillIds.contains(localBill.id)) continue;
          final uuid = localBill.clientUuid.trim().toLowerCase();
          if (uuid.isEmpty || !activeRemoteBillUuids.contains(uuid)) {
            await _db.deleteBillById(localBill.id, softDelete: false);
            importedCount++;
          }
        }
      }

      final deletedBudgetCategories = await _db
          .watchDeletedBudgetCategories(userEmail: normalizedEmail)
          .first;
      final remoteBudgets = data['budgets'];
      if (remoteBudgets is List) {
        for (final item in remoteBudgets) {
          if (item is! Map) continue;
          final category = (item['category'] as String? ?? '').trim();
          final limitAmount = (item['limit_amount'] as num?)?.toDouble() ?? 0.0;
          final month = (item['month'] as num?)?.toInt();
          final year = (item['year'] as num?)?.toInt();
          if (category.isNotEmpty &&
              limitAmount > 0 &&
              !deletedBudgetCategories.contains(category.toLowerCase())) {
            await _db.upsertBudget(
              category: category,
              limitAmount: limitAmount,
              month: month,
              year: year,
              userEmail: normalizedEmail,
            );
          }
        }
      }

      final existingLocalCards = await _db.getAllCreditCardsIncludingDeleted(
        userEmail: normalizedEmail,
      );
      final deletedCardUuids = existingLocalCards
          .where((c) => c.deletedAt != null && c.clientUuid.trim().isNotEmpty)
          .map((c) => c.clientUuid.trim().toLowerCase())
          .toSet();
      if (deletedCardUuids.isNotEmpty) {
        hasUnpushedTombstones = true;
      }

      final remoteCreditCards = data['credit_cards'];
      if (data.containsKey('credit_cards') && remoteCreditCards is List) {
        final activeRemoteCardUuids = <String>{};

        for (final item in remoteCreditCards) {
          if (item is! Map) continue;
          if (item['deleted_at'] != null) continue;

          final clientUuid =
              (item['client_uuid'] as String? ?? '').trim().toLowerCase();
          final name = (item['name'] as String? ?? '').trim();
          final limitAmount = (item['limit_amount'] as num?)?.toDouble() ?? 0.0;
          if (clientUuid.isEmpty || name.isEmpty || limitAmount <= 0) {
            continue;
          }

          if (deletedCardUuids.contains(clientUuid)) {
            hasUnpushedTombstones = true;
            continue;
          }

          activeRemoteCardUuids.add(clientUuid);
          final targetMin =
              (item['target_min_percent'] as num?)?.toDouble() ?? 50.0;
          final targetMax =
              (item['target_max_percent'] as num?)?.toDouble() ?? 80.0;
          final dueDay = (item['due_day'] as num?)?.toInt() ?? 10;
          final isPrimary = item['is_primary'] == true;
          final manualInvoiceAmount =
              (item['manual_invoice_amount'] as num?)?.toDouble();
          final manualInvoiceMonth =
              (item['manual_invoice_month'] as String?)?.trim();
          final updatedAt = item['updated_at'] is String
              ? DateTime.tryParse(item['updated_at'] as String)?.toLocal()
              : null;

          final changed = await _db.upsertPulledCreditCard(
            clientUuid: clientUuid,
            userEmail: normalizedEmail,
            name: name,
            limitAmount: limitAmount,
            targetMinPercent: targetMin,
            targetMaxPercent: targetMax,
            dueDay: dueDay,
            isPrimary: isPrimary,
            manualInvoiceAmount: manualInvoiceAmount,
            manualInvoiceMonth: manualInvoiceMonth,
            updatedAt: updatedAt,
          );
          if (changed) {
            importedCount++;
          }
        }

        // Remove localmente apenas cartões já sincronizados que foram apagados em outro dispositivo
        for (final localCard in existingLocalCards) {
          if (localCard.deletedAt != null || !localCard.isSynced) continue;
          final uuid = localCard.clientUuid.trim().toLowerCase();
          if (uuid.isNotEmpty && !activeRemoteCardUuids.contains(uuid)) {
            await _db.deleteCreditCard(localCard.id, softDelete: false);
            importedCount++;
          }
        }
      }

      if (hasUnpushedTombstones) {
        await pushPendingTransactions(
          pendingTransactions: const [],
          jwtToken: jwtToken,
          userEmail: normalizedEmail,
        );
      }

      return importedCount;
    } catch (_) {
      return 0;
    }
  }

  List<Map<String, dynamic>> _serializeCreditCardsPayload(
    List<LocalCreditCard> cards,
  ) {
    return cards.map((card) {
      return <String, dynamic>{
        'client_uuid': card.clientUuid.isNotEmpty
            ? card.clientUuid
            : AppDatabase.generateClientUuid(),
        'name': card.name,
        'limit_amount': card.limitAmount,
        'target_min_percent': card.targetMinPercent,
        'target_max_percent': card.targetMaxPercent,
        'due_day': card.dueDay,
        'is_primary': card.isPrimary,
        if (card.manualInvoiceAmount != null &&
            card.manualInvoiceMonth != null &&
            card.manualInvoiceMonth!.trim().length == 7) ...{
          'manual_invoice_amount': card.manualInvoiceAmount,
          'manual_invoice_month': card.manualInvoiceMonth!.trim(),
        },
        'updated_at': (card.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        if (card.deletedAt != null)
          'deleted_at': card.deletedAt!.toUtc().toIso8601String(),
      };
    }).toList();
  }
}

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CloudSyncService(database: db);
});
