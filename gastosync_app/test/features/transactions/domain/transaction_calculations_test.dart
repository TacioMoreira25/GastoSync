import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/features/transactions/domain/models/transaction.dart';

void main() {
  group('TransactionCalculations & Validation Tests (US1)', () {
    test('Deve calcular corretamente saldo líquido com múltiplas receitas e despesas', () {
      final now = DateTime(2026, 10, 20);
      final transactions = [
        Transaction(
          id: 1,
          description: 'Salário Mensal',
          amount: 10000.0,
          date: now,
          type: TransactionType.income,
          category: 'Renda Principal',
        ),
        Transaction(
          id: 2,
          description: 'Freelance Consultoria',
          amount: 2500.50,
          date: now,
          type: TransactionType.income,
          category: 'Renda Extra',
        ),
        Transaction(
          id: 3,
          description: 'Aluguel e Condomínio',
          amount: 3200.0,
          date: now,
          type: TransactionType.expense,
          category: 'Moradia',
        ),
        Transaction(
          id: 4,
          description: 'Supermercado Mensal',
          amount: 1450.25,
          date: now,
          type: TransactionType.expense,
          category: 'Alimentação',
        ),
      ];

      final totalIncome = TransactionCalculations.calculateTotalIncome(transactions);
      final totalExpense = TransactionCalculations.calculateTotalExpense(transactions);
      final netBalance = TransactionCalculations.calculateNetBalance(transactions);

      expect(totalIncome, closeTo(12500.50, 0.001));
      expect(totalExpense, closeTo(4650.25, 0.001));
      expect(netBalance, closeTo(7850.25, 0.001));
    });

    test('Deve retornar saldo zero para lista vazia de transações', () {
      expect(TransactionCalculations.calculateNetBalance(const []), equals(0.0));
      expect(TransactionCalculations.calculateTotalIncome(const []), equals(0.0));
      expect(TransactionCalculations.calculateTotalExpense(const []), equals(0.0));
    });

    test('Deve bloquear transação com valor negativo ou igual a zero (FR-009)', () {
      final zeroTx = Transaction(
        description: 'Teste valor zero',
        amount: 0,
        date: DateTime(2026, 10, 20),
        type: TransactionType.expense,
        category: 'Outros',
      );
      final negativeTx = Transaction(
        description: 'Teste valor negativo',
        amount: -50.0,
        date: DateTime(2026, 10, 20),
        type: TransactionType.expense,
        category: 'Outros',
      );

      expect(() => zeroTx.validate(), throwsA(isA<TransactionValidationException>()));
      expect(() => negativeTx.validate(), throwsA(isA<TransactionValidationException>()));
    });

    test('Deve bloquear transação com descrição vazia (FR-009)', () {
      final emptyDescTx = Transaction(
        description: '   ',
        amount: 45.0,
        date: DateTime(2026, 10, 20),
        type: TransactionType.expense,
        category: 'Alimentação',
      );

      expect(() => emptyDescTx.validate(), throwsA(isA<TransactionValidationException>()));
    });
  });
}
