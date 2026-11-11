import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';

enum BillStatus {
  pending('pending', 'Pendente'),
  paid('paid', 'Pago'),
  overdue('overdue', 'Vencido');

  const BillStatus(this.value, this.label);
  final String value;
  final String label;

  static BillStatus fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'paid':
        return BillStatus.paid;
      case 'overdue':
        return BillStatus.overdue;
      case 'pending':
      default:
        return BillStatus.pending;
    }
  }
}

class BillValidationException implements Exception {
  const BillValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class Bill {
  const Bill({
    this.id,
    this.clientUuid = '',
    this.userEmail,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.category,
    this.barcode = '',
    this.isRecurring = false,
    this.isCreditCardCharge = false,
    this.creditCardUuid,
    this.status = BillStatus.pending,
    this.paidAt,
    this.linkedTransactionId,
    this.linkedTxUuid,
    this.isSynced = false,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String clientUuid;
  final String? userEmail;
  final String description;
  final double amount;
  final DateTime dueDate;
  final String category;
  final String barcode;
  final bool isRecurring;

  /// Se `true`, representa uma cobrança/assinatura lançada diretamente na fatura
  /// do cartão de crédito (FR-011b): dispara os 2 lembretes diários e aloca na
  /// categoria orçamentária, mas NÃO soma em duplicidade no total de boletos a
  /// pagar nem reduz duas vezes o saldo líquido ao dar baixa.
  final bool isCreditCardCharge;
  final String? creditCardUuid;
  final BillStatus status;
  final DateTime? paidAt;
  final int? linkedTransactionId;
  final String? linkedTxUuid;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isPaid => status == BillStatus.paid;
  bool get isDeleted => deletedAt != null;
  bool get hasBarcode => barcode.trim().isNotEmpty;

  /// Retorna a diferença em dias inteiros entre a data de vencimento e [referenceDate] (padrão: hoje).
  /// Valores negativos indicam dias em atraso; `0` indica que vence hoje; positivos indicam dias restantes.
  int daysUntilDue([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final targetDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return targetDueDate.difference(todayDate).inDays;
  }

  /// Indica se o boleto não está pago e vence exatamente na data de referência (hoje).
  bool isDueToday([DateTime? referenceDate]) {
    if (isPaid) return false;
    return daysUntilDue(referenceDate) == 0;
  }

  /// Indica se o boleto não está pago e já ultrapassou a data de vencimento (ou está marcado como `overdue`).
  bool isOverdue([DateTime? referenceDate]) {
    if (isPaid) return false;
    return status == BillStatus.overdue || daysUntilDue(referenceDate) < 0;
  }

  /// Indica se o boleto não está pago e vence hoje ou dentro dos próximos [withinDays] dias (padrão: 3 dias).
  bool isDueSoon({DateTime? referenceDate, int withinDays = 3}) {
    if (isPaid) return false;
    final days = daysUntilDue(referenceDate);
    return days >= 0 && days <= withinDays;
  }

  /// Indica se o boleto requer alerta nos lembretes diários (vencido, vence hoje ou vence em até 3 dias).
  bool requiresReminderAlert([DateTime? referenceDate]) {
    if (isPaid || isDeleted) return false;
    return isOverdue(referenceDate) || isDueSoon(referenceDate: referenceDate);
  }

  /// Status efetivo considerando a data atual para destacar boletos vencidos mesmo antes de persistir status.
  BillStatus effectiveStatus([DateTime? referenceDate]) {
    if (isPaid) return BillStatus.paid;
    if (isOverdue(referenceDate)) return BillStatus.overdue;
    return BillStatus.pending;
  }

  /// Calcula a data de vencimento do mês seguinte preservando o dia original e
  /// ajustando automaticamente os dias 28/29/30/31 para o último dia válido do mês subsequente.
  static DateTime calculateNextMonthDueDate(DateTime currentDueDate) {
    final nextYear = currentDueDate.month == 12
        ? currentDueDate.year + 1
        : currentDueDate.year;
    final nextMonth =
        currentDueDate.month == 12 ? 1 : currentDueDate.month + 1;

    // O dia 0 do mês seguinte a `nextMonth` retorna o último dia válido de `nextMonth`
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

  /// Data de vencimento calculada para o próximo ciclo mensal.
  DateTime get nextMonthDueDate => calculateNextMonthDueDate(dueDate);

  /// Gera a instância do próximo boleto pendente quando [isRecurring] é verdadeiro.
  Bill createNextRecurringBill({String? nextClientUuid, DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return Bill(
      clientUuid: nextClientUuid ?? '',
      userEmail: userEmail,
      description: description,
      amount: amount,
      dueDate: nextMonthDueDate,
      category: category,
      barcode: barcode,
      isRecurring: isRecurring,
      isCreditCardCharge: isCreditCardCharge,
      creditCardUuid: creditCardUuid,
      status: BillStatus.pending,
      isSynced: false,
      updatedAt: timestamp,
    );
  }

  /// Valida regras de domínio (FR-010): valor > 0, descrição de 1 a 255 caracteres, categoria obrigatória.
  void validate() {
    if (description.trim().isEmpty) {
      throw const BillValidationException(
        'A descrição do boleto/conta não pode ser vazia.',
      );
    }
    if (description.trim().length > 255) {
      throw const BillValidationException(
        'A descrição do boleto deve ter no máximo 255 caracteres.',
      );
    }
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw const BillValidationException(
        'O valor do boleto deve ser maior que zero.',
      );
    }
    if (category.trim().isEmpty) {
      throw const BillValidationException(
        'A categoria do boleto é obrigatória.',
      );
    }
  }

  factory Bill.fromLocal(LocalBill row) {
    return Bill(
      id: row.id,
      clientUuid: row.clientUuid,
      userEmail: row.userEmail,
      description: row.description,
      amount: row.amount,
      dueDate: row.dueDate,
      category: row.category,
      barcode: row.barcode,
      isRecurring: row.isRecurring,
      isCreditCardCharge: row.isCreditCardCharge,
      creditCardUuid: row.creditCardUuid,
      status: BillStatus.fromString(row.status),
      paidAt: row.paidAt,
      linkedTransactionId: row.linkedTransactionId,
      linkedTxUuid: row.linkedTxUuid,
      isSynced: row.isSynced,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  LocalBillsCompanion toCompanion() {
    validate();
    return LocalBillsCompanion(
      id: id != null ? drift.Value(id!) : const drift.Value.absent(),
      clientUuid: clientUuid.trim().isNotEmpty
          ? drift.Value(clientUuid.trim())
          : const drift.Value.absent(),
      userEmail: userEmail != null && userEmail!.trim().isNotEmpty
          ? drift.Value(userEmail!.trim().toLowerCase())
          : const drift.Value.absent(),
      description: drift.Value(description.trim()),
      amount: drift.Value(amount),
      dueDate: drift.Value(dueDate),
      category: drift.Value(category.trim()),
      barcode: drift.Value(barcode.trim()),
      isRecurring: drift.Value(isRecurring),
      isCreditCardCharge: drift.Value(isCreditCardCharge),
      creditCardUuid: creditCardUuid != null && creditCardUuid!.trim().isNotEmpty
          ? drift.Value(creditCardUuid!.trim())
          : const drift.Value(null),
      status: drift.Value(status.value),
      paidAt: drift.Value(paidAt),
      linkedTransactionId: drift.Value(linkedTransactionId),
      linkedTxUuid: drift.Value(linkedTxUuid),
      isSynced: drift.Value(isSynced),
      updatedAt: drift.Value(updatedAt ?? DateTime.now()),
      deletedAt: drift.Value(deletedAt),
    );
  }

  factory Bill.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final parsedAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0;

    return Bill(
      id: (json['local_id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt(),
      clientUuid: (json['client_uuid'] as String?) ?? '',
      userEmail: json['user_email'] as String?,
      description: (json['description'] as String?) ?? '',
      amount: parsedAmount,
      dueDate: DateTime.tryParse((json['due_date'] as String?) ?? '') ??
          DateTime.now(),
      category: (json['category'] as String?) ?? 'Outros',
      barcode: (json['barcode'] as String?) ?? '',
      isRecurring: (json['is_recurring'] as bool?) ?? false,
      isCreditCardCharge: (json['is_credit_card_charge'] as bool?) ?? false,
      creditCardUuid: json['credit_card_uuid'] as String?,
      status: BillStatus.fromString((json['status'] as String?) ?? 'pending'),
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      linkedTxUuid: json['linked_tx_uuid'] as String?,
      isSynced: true,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'local_id': id,
      if (clientUuid.trim().isNotEmpty) 'client_uuid': clientUuid.trim(),
      'description': description.trim(),
      'amount': amount,
      'due_date': dueDate.toUtc().toIso8601String(),
      'category': category.trim(),
      'barcode': barcode.trim(),
      'is_recurring': isRecurring,
      'is_credit_card_charge': isCreditCardCharge,
      if (creditCardUuid != null && creditCardUuid!.trim().isNotEmpty)
        'credit_card_uuid': creditCardUuid!.trim(),
      'status': status.value,
      if (paidAt != null) 'paid_at': paidAt!.toUtc().toIso8601String(),
      if (linkedTxUuid != null && linkedTxUuid!.trim().isNotEmpty)
        'linked_tx_uuid': linkedTxUuid!.trim(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  Bill copyWith({
    int? id,
    String? clientUuid,
    String? userEmail,
    String? description,
    double? amount,
    DateTime? dueDate,
    String? category,
    String? barcode,
    bool? isRecurring,
    bool? isCreditCardCharge,
    String? creditCardUuid,
    bool clearCreditCardUuid = false,
    BillStatus? status,
    DateTime? paidAt,
    bool clearPaidAt = false,
    int? linkedTransactionId,
    String? linkedTxUuid,
    bool? isSynced,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Bill(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      userEmail: userEmail ?? this.userEmail,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      isRecurring: isRecurring ?? this.isRecurring,
      isCreditCardCharge: isCreditCardCharge ?? this.isCreditCardCharge,
      creditCardUuid: clearCreditCardUuid
          ? null
          : (creditCardUuid ?? this.creditCardUuid),
      status: status ?? this.status,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      linkedTxUuid: linkedTxUuid ?? this.linkedTxUuid,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

/// Utilitário de domínio para consolidação de boletos e proteção contra dupla contagem de faturas (FR-011b)
class BillCalculations {
  BillCalculations._();

  /// Soma o total de boletos pendentes/vencidos que efetivamente representam saída de caixa adicional
  /// (exclui itens com `isCreditCardCharge == true`, que já estão inclusos na fatura do cartão).
  static double calculateTotalPendingCashOutflow(Iterable<Bill> bills) {
    return bills
        .where((b) => !b.isDeleted && !b.isPaid && !b.isCreditCardCharge)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  /// Soma o total de cobranças recorrentes no cartão de crédito (`isCreditCardCharge == true`) ativas.
  static double calculateTotalCreditCardCharges(Iterable<Bill> bills) {
    return bills
        .where((b) => !b.isDeleted && b.isCreditCardCharge)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  /// Soma o total de boletos pagos (exceto cobranças embutidas no cartão).
  static double calculateTotalPaid(Iterable<Bill> bills) {
    return bills
        .where((b) => !b.isDeleted && b.isPaid && !b.isCreditCardCharge)
        .fold(0.0, (sum, b) => sum + b.amount);
  }
}
