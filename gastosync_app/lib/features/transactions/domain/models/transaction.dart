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
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.isSynced = false,
  });

  final int? id;
  final String description;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String category;
  final bool isSynced;

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

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
  }

  factory Transaction.fromLocal(LocalTransaction row) {
    return Transaction(
      id: row.id,
      description: row.description,
      amount: row.amount,
      date: row.date,
      type: TransactionType.fromString(row.type),
      category: row.category,
      isSynced: row.isSynced,
    );
  }

  LocalTransactionsCompanion toCompanion() {
    validate();
    return LocalTransactionsCompanion(
      id: id != null ? drift.Value(id!) : const drift.Value.absent(),
      description: drift.Value(description.trim()),
      amount: drift.Value(amount),
      date: drift.Value(date),
      type: drift.Value(type.value),
      category: drift.Value(category.trim()),
      isSynced: drift.Value(isSynced),
    );
  }

  Transaction copyWith({
    int? id,
    String? description,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    bool? isSynced,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

/// Utilitário de domínio para cálculos diretos sobre listas de transações
class TransactionCalculations {
  TransactionCalculations._();

  static double calculateTotalIncome(Iterable<Transaction> transactions) {
    return transactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateTotalExpense(Iterable<Transaction> transactions) {
    return transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateNetBalance(Iterable<Transaction> transactions) {
    return calculateTotalIncome(transactions) -
        calculateTotalExpense(transactions);
  }
}
