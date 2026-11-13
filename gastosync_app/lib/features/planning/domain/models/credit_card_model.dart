import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../../transactions/domain/models/bill.dart';
import '../../../transactions/domain/models/transaction.dart';

class CreditCardValidationException implements Exception {
  const CreditCardValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Modelo de domínio para Gestão de Cartões de Crédito (Principal e Secundários)
/// e Faixa Saudável de Relacionamento Bancário (ex.: 50% a 80% do limite) (T028 / US5).
/// Em conformidade com PCI/OWASP, armazena apenas apelido, limite, dia de vencimento
/// e metas percentuais — nunca número do cartão (PAN), CVV ou validade.
@immutable
class CreditCard {
  const CreditCard({
    this.id,
    this.clientUuid = '',
    this.userEmail,
    required this.name,
    required this.limitAmount,
    this.targetMinPercent = 50.0,
    this.targetMaxPercent = 80.0,
    this.dueDay = 10,
    this.isPrimary = false,
    this.isSynced = false,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String clientUuid;
  final String? userEmail;
  final String name;
  final double limitAmount;
  final double targetMinPercent;
  final double targetMaxPercent;
  final int dueDay;
  final bool isPrimary;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Valor em Reais correspondente ao piso da faixa ideal de relacionamento (ex.: 50% de R$ 1.500 = R$ 750,00)
  double get healthyMinAmount =>
      limitAmount * (targetMinPercent.clamp(0.0, 100.0) / 100.0);

  /// Valor em Reais correspondente ao teto saudável de utilização (ex.: 80% de R$ 1.500 = R$ 1.200,00)
  double get healthyMaxAmount =>
      limitAmount * (targetMaxPercent.clamp(0.0, 100.0) / 100.0);

  void validate() {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const CreditCardValidationException(
        'Informe um nome para o cartão (ex: Cartão Principal).',
      );
    }
    if (trimmedName.length > 100) {
      throw const CreditCardValidationException(
        'O nome do cartão deve ter no máximo 100 caracteres.',
      );
    }
    if (limitAmount.isNaN || limitAmount.isInfinite || limitAmount <= 0) {
      throw const CreditCardValidationException(
        'O limite do cartão deve ser maior que zero.',
      );
    }
    if (dueDay < 1 || dueDay > 31) {
      throw const CreditCardValidationException(
        'O dia de vencimento da fatura deve estar entre 1 e 31.',
      );
    }
    if (targetMinPercent < 0 ||
        targetMaxPercent > 100 ||
        targetMinPercent > targetMaxPercent) {
      throw const CreditCardValidationException(
        'A faixa saudável de uso deve estar entre 0% e 100% (mínimo <= máximo).',
      );
    }
  }

  factory CreditCard.fromLocal(LocalCreditCard row) {
    return CreditCard(
      id: row.id,
      clientUuid: row.clientUuid,
      userEmail: row.userEmail,
      name: row.name,
      limitAmount: row.limitAmount,
      targetMinPercent: row.targetMinPercent,
      targetMaxPercent: row.targetMaxPercent,
      dueDay: row.dueDay,
      isPrimary: row.isPrimary,
      isSynced: row.isSynced,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  LocalCreditCardsCompanion toCompanion() {
    validate();
    final resolvedUuid = clientUuid.trim().isNotEmpty
        ? clientUuid.trim()
        : AppDatabase.generateClientUuid();

    return LocalCreditCardsCompanion(
      id: id != null ? drift.Value(id!) : const drift.Value.absent(),
      clientUuid: drift.Value(resolvedUuid),
      userEmail: userEmail != null && userEmail!.trim().isNotEmpty
          ? drift.Value(userEmail!.trim().toLowerCase())
          : const drift.Value.absent(),
      name: drift.Value(name.trim()),
      limitAmount: drift.Value(limitAmount),
      targetMinPercent: drift.Value(targetMinPercent),
      targetMaxPercent: drift.Value(targetMaxPercent),
      dueDay: drift.Value(dueDay.clamp(1, 31)),
      isPrimary: drift.Value(isPrimary),
      isSynced: drift.Value(isSynced),
      updatedAt: drift.Value(updatedAt ?? DateTime.now()),
      deletedAt: deletedAt != null
          ? drift.Value(deletedAt)
          : const drift.Value.absent(),
    );
  }

  CreditCard copyWith({
    int? id,
    String? clientUuid,
    String? userEmail,
    String? name,
    double? limitAmount,
    double? targetMinPercent,
    double? targetMaxPercent,
    int? dueDay,
    bool? isPrimary,
    bool? isSynced,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CreditCard(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      userEmail: userEmail ?? this.userEmail,
      name: name ?? this.name,
      limitAmount: limitAmount ?? this.limitAmount,
      targetMinPercent: targetMinPercent ?? this.targetMinPercent,
      targetMaxPercent: targetMaxPercent ?? this.targetMaxPercent,
      dueDay: dueDay ?? this.dueDay,
      isPrimary: isPrimary ?? this.isPrimary,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

/// Resumo consolidado do uso mensal de um cartão de crédito, separando
/// assinaturas/cobranças fixas (`fixedSubscriptionsAmount`) e compras avulsas
/// no crédito (`variablePurchasesAmount`), além dos indicadores da faixa saudável
/// de relacionamento bancário (50% a 80%) (T028 / US5).
@immutable
class CreditCardUsageSummary {
  const CreditCardUsageSummary({
    required this.card,
    required this.fixedSubscriptionsAmount,
    required this.variablePurchasesAmount,
    this.fixedSubscriptionsCount = 0,
    this.variablePurchasesCount = 0,
  });

  final CreditCard card;

  /// Soma das cobranças recorrentes/fixas na fatura (`Bill.isCreditCardCharge == true`) do mês
  final double fixedSubscriptionsAmount;

  /// Soma das compras variáveis no cartão (`Transaction.paymentMethod == 'Crédito'`) do mês
  final double variablePurchasesAmount;

  final int fixedSubscriptionsCount;
  final int variablePurchasesCount;

  /// Total utilizado no cartão no mês (Fixas + Variáveis)
  double get totalUsedAmount =>
      fixedSubscriptionsAmount + variablePurchasesAmount;

  /// Percentual de utilização sobre o limite total do cartão (`0`..`100+`)
  double get utilizationPercent =>
      card.limitAmount > 0 ? (totalUsedAmount / card.limitAmount) * 100.0 : 0.0;

  /// Piso da faixa saudável em Reais (ex.: 50% de R$ 1.500 = R$ 750,00)
  double get healthyMinAmount => card.healthyMinAmount;

  /// Teto da faixa saudável em Reais (ex.: 80% de R$ 1.500 = R$ 1.200,00)
  double get healthyMaxAmount => card.healthyMaxAmount;

  /// Margem restante em Reais até atingir o teto saudável configurado (ex.: 80%)
  double get remainingHealthyMargin =>
      math.max(0.0, healthyMaxAmount - totalUsedAmount);

  /// Limite total restante em Reais até atingir 100% do limite do cartão
  double get remainingTotalLimit =>
      math.max(0.0, card.limitAmount - totalUsedAmount);

  /// Valor excedente acima do teto saudável configurado (`0.0` se estiver dentro do teto)
  double get amountAboveHealthyCeiling =>
      math.max(0.0, totalUsedAmount - healthyMaxAmount);

  /// Indica se o uso está abaixo do piso da faixa ideal (ex.: `< 50%`)
  bool get isBelowHealthyMin => totalUsedAmount < healthyMinAmount;

  /// Indica se o uso está exatamente dentro da faixa saudável de relacionamento (ex.: `50%` a `80%`)
  bool get isInHealthySweetSpot =>
      totalUsedAmount >= healthyMinAmount &&
      totalUsedAmount <= healthyMaxAmount;

  /// Indica se o uso ultrapassou o teto saudável configurado (ex.: `> 80%`)
  bool get isAboveHealthyCeiling => totalUsedAmount > healthyMaxAmount;

  /// Indica se o uso ultrapassou 100% do limite total do cartão
  bool get isLimitExceeded => totalUsedAmount > card.limitAmount;

  String get relationshipStatusLabel {
    if (isLimitExceeded) {
      return 'Limite total excedido (${utilizationPercent.toStringAsFixed(1)}%)';
    }
    if (isAboveHealthyCeiling) {
      return 'Acima do teto saudável de ${card.targetMaxPercent.toStringAsFixed(0)}%';
    }
    if (isInHealthySweetSpot) {
      return 'Faixa ideal de relacionamento (${card.targetMinPercent.toStringAsFixed(0)}%–${card.targetMaxPercent.toStringAsFixed(0)}%)';
    }
    return 'Uso leve • Meta ideal: ${card.targetMinPercent.toStringAsFixed(0)}% a ${card.targetMaxPercent.toStringAsFixed(0)}%';
  }

  static bool _isCreditPaymentMethod(String method) {
    final lower = method.trim().toLowerCase();
    return lower == 'crédito' ||
        lower == 'credito' ||
        lower == 'cartão de crédito' ||
        lower == 'cartao de credito';
  }

  ///Calcula o resumo de uso de um único cartão no mês de [referenceDate].
  /// Quando `card.isPrimary == true`, compras no crédito e cobranças fixas no cartão
  /// que não possuam `creditCardUuid` explícito são atribuídas automaticamente ao Cartão Principal.
  static CreditCardUsageSummary calculateForCard({
    required CreditCard card,
    required Iterable<Transaction> transactions,
    required Iterable<Bill> bills,
    DateTime? referenceDate,
    bool fallbackUnassignedToThisCard = false,
  }) {
    final now = referenceDate ?? DateTime.now();
    final cardUuid = card.clientUuid.trim();
    final acceptUnassigned = card.isPrimary || fallbackUnassignedToThisCard;

    bool matchesCard(String? itemCardUuid) {
      final normalized = itemCardUuid?.trim() ?? '';
      if (normalized.isEmpty) {
        return acceptUnassigned;
      }
      return cardUuid.isNotEmpty && normalized == cardUuid;
    }

    double fixedSum = 0.0;
    int fixedCount = 0;
    for (final bill in bills) {
      if (bill.isDeleted || !bill.isCreditCardCharge) continue;
      if (bill.dueDate.year != now.year || bill.dueDate.month != now.month) {
        continue;
      }
      if (matchesCard(bill.creditCardUuid)) {
        fixedSum += bill.amount;
        fixedCount++;
      }
    }

    double variableSum = 0.0;
    int variableCount = 0;
    for (final tx in transactions) {
      if (tx.isDeleted || !tx.isExpense) continue;
      if (tx.date.year != now.year || tx.date.month != now.month) continue;
      if (!_isCreditPaymentMethod(tx.paymentMethod)) continue;
      if (matchesCard(tx.creditCardUuid)) {
        variableSum += tx.amount;
        variableCount++;
      }
    }

    return CreditCardUsageSummary(
      card: card,
      fixedSubscriptionsAmount: fixedSum,
      variablePurchasesAmount: variableSum,
      fixedSubscriptionsCount: fixedCount,
      variablePurchasesCount: variableCount,
    );
  }

  /// Calcula o resumo de todos os cartões ativos do usuário.
  static List<CreditCardUsageSummary> calculateAll({
    required List<CreditCard> cards,
    required Iterable<Transaction> transactions,
    required Iterable<Bill> bills,
    DateTime? referenceDate,
  }) {
    final activeCards = cards.where((c) => !c.isDeleted).toList();
    if (activeCards.isEmpty) return const <CreditCardUsageSummary>[];

    final hasPrimary = activeCards.any((c) => c.isPrimary);
    return [
      for (var i = 0; i < activeCards.length; i++)
        calculateForCard(
          card: activeCards[i],
          transactions: transactions,
          bills: bills,
          referenceDate: referenceDate,
          fallbackUnassignedToThisCard: !hasPrimary && i == 0,
        ),
    ];
  }
}
