import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';

enum TransactionType {
  income('income', 'Receita'),
  expense('expense', 'Despesa');

  const TransactionType(this.value, this.label);
  final String value;
  final String label;

  static TransactionType fromString(String raw) {
    return raw.toLowerCase() == 'income'
        ? TransactionType.income
        : TransactionType.expense;
  }
}

class TransactionValidationException implements Exception {
  const TransactionValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class Transaction {
  const Transaction({
    this.id,
    this.clientUuid = '',
    this.userEmail,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.paymentMethod = 'PIX',
    this.creditCardUuid,
    this.isSynced = false,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String clientUuid;
  final String? userEmail;
  final String description;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String category;
  final String paymentMethod;
  final String? creditCardUuid;
  final bool isSynced;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
  bool get isDeleted => deletedAt != null;

  /// Valida regras de domínio (FR-009): valor > 0, descrição não vazia
  void validate() {
    if (description.trim().isEmpty) {
      throw const TransactionValidationException(
        'A descrição da transação não pode ser vazia.',
      );
    }
    if (description.trim().length > 255) {
      throw const TransactionValidationException(
        'A descrição deve ter no máximo 255 caracteres.',
      );
    }
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw const TransactionValidationException(
        'O valor da transação deve ser maior que zero.',
      );
    }
    if (category.trim().isEmpty) {
      throw const TransactionValidationException(
        'A categoria da transação é obrigatória.',
      );
    }
    if (isExpense && category.trim().toLowerCase().startsWith('renda')) {
      throw const TransactionValidationException(
        'Nenhuma despesa pode ter a categoria Renda.',
      );
    }
  }

  factory Transaction.fromLocal(LocalTransaction row) {
    final normalizedMethod = row.paymentMethod.trim();
    return Transaction(
      id: row.id,
      clientUuid: row.clientUuid,
      userEmail: row.userEmail,
      description: row.description,
      amount: row.amount,
      date: row.date,
      type: TransactionType.fromString(row.type),
      category: row.category,
      paymentMethod: normalizedMethod.isEmpty ? 'PIX' : normalizedMethod,
      creditCardUuid: row.creditCardUuid,
      isSynced: row.isSynced,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  LocalTransactionsCompanion toCompanion() {
    validate();
    final resolvedUuid = clientUuid.trim().isNotEmpty
        ? clientUuid.trim()
        : AppDatabase.generateClientUuid();
    final resolvedMethod =
        paymentMethod.trim().isEmpty ? 'PIX' : paymentMethod.trim();
    final resolvedCardUuid =
        (creditCardUuid != null && creditCardUuid!.trim().isNotEmpty)
            ? creditCardUuid!.trim()
            : null;

    return LocalTransactionsCompanion(
      id: id != null ? drift.Value(id!) : const drift.Value.absent(),
      clientUuid: drift.Value(resolvedUuid),
      userEmail: userEmail != null && userEmail!.trim().isNotEmpty
          ? drift.Value(userEmail!.trim().toLowerCase())
          : const drift.Value.absent(),
      description: drift.Value(description.trim()),
      amount: drift.Value(amount),
      date: drift.Value(date),
      type: drift.Value(type.value),
      category: drift.Value(category.trim()),
      paymentMethod: drift.Value(resolvedMethod),
      creditCardUuid: drift.Value(resolvedCardUuid),
      isSynced: drift.Value(isSynced),
      updatedAt: drift.Value(updatedAt ?? DateTime.now()),
      deletedAt: deletedAt != null
          ? drift.Value(deletedAt)
          : const drift.Value.absent(),
    );
  }

  Transaction copyWith({
    int? id,
    String? clientUuid,
    String? userEmail,
    String? description,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? paymentMethod,
    String? creditCardUuid,
    bool clearCreditCardUuid = false,
    bool? isSynced,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      userEmail: userEmail ?? this.userEmail,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      creditCardUuid: clearCreditCardUuid
          ? null
          : (creditCardUuid ?? this.creditCardUuid),
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

/// Utilitário de domínio para cálculos diretos sobre listas de transações
class TransactionCalculations {
  TransactionCalculations._();

  static double calculateTotalIncome(Iterable<Transaction> transactions) {
    return transactions
        .where((t) => t.isIncome && !t.isDeleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateTotalExpense(Iterable<Transaction> transactions) {
    return transactions
        .where((t) => t.isExpense && !t.isDeleted)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateNetBalance(Iterable<Transaction> transactions) {
    return calculateTotalIncome(transactions) -
        calculateTotalExpense(transactions);
  }
}
