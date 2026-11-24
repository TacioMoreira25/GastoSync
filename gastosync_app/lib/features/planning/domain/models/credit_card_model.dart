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
    this.closingDay = 3,
    this.isPrimary = false,
    this.manualInvoiceAmount,
    this.manualInvoiceMonth,
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
  final int closingDay;
  final bool isPrimary;
  final double? manualInvoiceAmount;
  final String? manualInvoiceMonth;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  static String formatYearMonth(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Retorna o intervalo real `(inicio, fim)` de compras que entram na fatura
  /// com vencimento no mês de [referenceDate], considerando [closingDay] e [dueDay].
  ({DateTime start, DateTime end}) invoiceCycleForMonth(
    DateTime referenceDate,
  ) {
    final safeClosing = closingDay.clamp(1, 31);
    final safeDue = dueDay.clamp(1, 31);
    // Se fecha depois do vencimento (ex.: fecha 25, vence 05), o fechamento da fatura
    // de Dezembro ocorreu em Novembro (25/11); caso contrário (ex.: fecha 21, vence 28),
    // ocorre no próprio mês (21/12).
    final endBase = safeClosing > safeDue
        ? DateTime(referenceDate.year, referenceDate.month - 1, 1)
        : DateTime(referenceDate.year, referenceDate.month, 1);
    final endLastDay = DateTime(endBase.year, endBase.month + 1, 0).day;
    final endDay = safeClosing > endLastDay ? endLastDay : safeClosing;
    final end = DateTime(endBase.year, endBase.month, endDay, 23, 59, 59);

    final prevBase = DateTime(endBase.year, endBase.month - 1, 1);
    final prevLastDay = DateTime(prevBase.year, prevBase.month + 1, 0).day;
    final prevClosingDay =
        safeClosing > prevLastDay ? prevLastDay : safeClosing;
    final prevClosing = DateTime(prevBase.year, prevBase.month, prevClosingDay);
    final start = DateTime(
      prevClosing.year,
      prevClosing.month,
      prevClosing.day,
    ).add(const Duration(days: 1));
    return (start: start, end: end);
  }

  /// Retorna o valor de fatura informado manualmente se pertencer ao mês de [referenceDate].
  double? manualInvoiceForMonth([DateTime? referenceDate]) {
    if (manualInvoiceAmount == null || manualInvoiceAmount! < 0) return null;
    final refMonth = formatYearMonth(referenceDate ?? DateTime.now());
    if (manualInvoiceMonth?.trim() != refMonth) return null;
    return manualInvoiceAmount;
  }

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
      closingDay: row.closingDay,
      isPrimary: row.isPrimary,
      manualInvoiceAmount: row.manualInvoiceAmount,
      manualInvoiceMonth: row.manualInvoiceMonth,
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
      closingDay: drift.Value(closingDay.clamp(1, 31)),
      isPrimary: drift.Value(isPrimary),
      manualInvoiceAmount: drift.Value(manualInvoiceAmount),
      manualInvoiceMonth: drift.Value(manualInvoiceMonth),
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
    int? closingDay,
    bool? isPrimary,
    double? manualInvoiceAmount,
    String? manualInvoiceMonth,
    bool clearManualInvoice = false,
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
      closingDay: closingDay ?? this.closingDay,
      isPrimary: isPrimary ?? this.isPrimary,
      manualInvoiceAmount: clearManualInvoice
          ? null
          : (manualInvoiceAmount ?? this.manualInvoiceAmount),
      manualInvoiceMonth: clearManualInvoice
          ? null
          : (manualInvoiceMonth ?? this.manualInvoiceMonth),
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

/// Resumo consolidado do uso mensal de um cartão de crédito, separando
/// assinaturas/cobranças fixas (`fixedSubscriptionsAmount`) e compras avulsas
/// no crédito (`variablePurchasesAmount`), além do valor manual opcional da fatura
/// (`manualInvoiceAmount`) e dos indicadores da faixa saudável (50% a 80%) (T028 / US5).
@immutable
class CreditCardUsageSummary {
  const CreditCardUsageSummary({
    required this.card,
    required this.fixedSubscriptionsAmount,
    required this.variablePurchasesAmount,
    this.fixedSubscriptionsCount = 0,
    this.variablePurchasesCount = 0,
    this.manualInvoiceAmount,
  });

  final CreditCard card;

  /// Soma das cobranças recorrentes/fixas na fatura (`Bill.isCreditCardCharge == true`) do mês
  final double fixedSubscriptionsAmount;

  /// Soma das compras variáveis no cartão (`Transaction.paymentMethod == 'Crédito'`) do mês
  final double variablePurchasesAmount;

  final int fixedSubscriptionsCount;
  final int variablePurchasesCount;

  /// Valor de fatura informado manualmente pelo usuário para o mês vigente (opcional)
  final double? manualInvoiceAmount;

  /// Indica se há um valor de fatura informado manualmente ativo para este mês
  bool get hasManualInvoice => manualInvoiceAmount != null;

  /// Soma detalhada no app (Fixas + Variáveis lançadas no cartão)
  double get trackedUsedAmount =>
      fixedSubscriptionsAmount + variablePurchasesAmount;

  /// Diferença entre a fatura informada manualmente e o que foi detalhado no app
  /// (positivo = gastos anteriores/não lançados no app; negativo = lançamentos no app superaram o valor informado)
  double get untrackedInvoiceDifference =>
      hasManualInvoice ? (manualInvoiceAmount! - trackedUsedAmount) : 0.0;

  /// Total utilizado no cartão no mês: usa o valor informado da fatura quando definido,
  /// ou a soma automática das compras e cobranças fixas lançadas no app.
  double get totalUsedAmount =>
      hasManualInvoice ? manualInvoiceAmount! : trackedUsedAmount;

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

    final cycle = card.invoiceCycleForMonth(now);

    double fixedSum = 0.0;
    int fixedCount = 0;
    for (final bill in bills) {
      if (bill.isDeleted || !bill.isCreditCardCharge) continue;
      if (bill.dueDate.isBefore(cycle.start) ||
          bill.dueDate.isAfter(cycle.end)) {
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
      if (tx.date.isBefore(cycle.start) || tx.date.isAfter(cycle.end)) {
        continue;
      }
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
      manualInvoiceAmount: card.manualInvoiceForMonth(now),
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
