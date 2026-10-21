import 'dart:math' as math;
import '../../../../core/database/app_database.dart';
import '../../../transactions/domain/models/transaction.dart';

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.month,
    required this.year,
    required this.label,
    required this.income,
    required this.expense,
  });

  final int month;
  final int year;
  final String label;
  final double income;
  final double expense;
}

class FinancialMetrics {
  const FinancialMetrics({
    required this.calculatedAt,
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.savingsRate,
    required this.emergencyMonths,
    required this.incomeCommitment,
    required this.dailyBurnRate,
    required this.monthEndProjection,
    required this.healthScore,
    required this.sixMonthsSeries,
  });

  final DateTime calculatedAt;
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final double emergencyMonths;
  final double incomeCommitment;
  final double dailyBurnRate;
  final double monthEndProjection;
  final double healthScore;
  final List<MonthlyCashFlowPoint> sixMonthsSeries;

  LocalMetricsCompanion toCompanion() {
    return LocalMetricsCompanion.insert(
      calculatedAt: calculatedAt,
      currentBalance: currentBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
      emergencyMonths: emergencyMonths,
      incomeCommitment: incomeCommitment,
      dailyBurnRate: dailyBurnRate,
      monthEndProjection: monthEndProjection,
      healthScore: healthScore,
    );
  }
}

/// Motor de domínio para cálculo determinístico e 100% local das 9 Métricas Canônicas (T029)
class FinancialHealthEngine {
  FinancialHealthEngine._();

  static const List<String> _monthShortNames = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  static FinancialMetrics calculate(
    List<Transaction> transactions, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // 1. Saldo Líquido Acumulado = sum(Receitas) - sum(Despesas)
    final currentBalance =
        TransactionCalculations.calculateNetBalance(transactions);

    // Filtra transações do mês vigente
    final currentMonthTxs = transactions.where(
      (t) => t.date.year == currentYear && t.date.month == currentMonth,
    );

    // 2. Receita Mensal Total
    final totalIncome =
        TransactionCalculations.calculateTotalIncome(currentMonthTxs);

    // 3. Despesa Mensal Total
    final totalExpense =
        TransactionCalculations.calculateTotalExpense(currentMonthTxs);

    // 4. Taxa de Poupança (%) = (Receita Mensal - Despesa Mensal) / Receita Mensal * 100
    final double savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome) * 100.0
        : 0.0;

    // 5. Reserva de Emergência em Meses = Saldo Líquido Acumulado / Média Mensal de Despesas (últimos 3 meses)
    final avgExpense3Months = _calculateAverageMonthlyExpenseLast3Months(
      transactions,
      now,
      currentMonthExpenseFallback: totalExpense,
    );
    final double emergencyMonths =
        (avgExpense3Months > 0 && currentBalance > 0)
            ? (currentBalance / avgExpense3Months)
            : 0.0;

    // 6. Comprometimento da Renda (%) = Despesa Mensal / Receita Mensal * 100
    final double incomeCommitment = totalIncome > 0
        ? (totalExpense / totalIncome) * 100.0
        : (totalExpense > 0 ? 100.0 : 0.0);

    // 7. Burn Rate Diário = Despesa Total do Mês / Dias Transcorridos do Mês Atual
    final elapsedDays = math.max(1, now.day);
    final dailyBurnRate = totalExpense / elapsedDays;

    // 8. Projeção de Fim de Mês = Despesa Atual + (Burn Rate Diário * Dias Restantes do Mês)
    final totalDaysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final remainingDays = math.max(0, totalDaysInMonth - elapsedDays);
    final monthEndProjection = totalExpense + (dailyBurnRate * remainingDays);

    // 9. Score de Saúde Financeira (0-100):
    // Score = (Poupança * 0.3) + (min(Reserva em Meses / 6, 1) * 35) + ((1 - min(ComprometimentoRatio, 1)) * 35)
    final clampedSavings = savingsRate.clamp(0.0, 100.0);
    final reserveFactor = math.min(emergencyMonths / 6.0, 1.0).clamp(0.0, 1.0);
    final commitmentRatio = (incomeCommitment / 100.0).clamp(0.0, 1.0);
    final double rawScore = (transactions.isEmpty)
        ? 0.0
        : (clampedSavings * 0.3) +
            (reserveFactor * 35.0) +
            ((1.0 - commitmentRatio) * 35.0);
    final healthScore = rawScore.clamp(0.0, 100.0);

    // Série histórica dos últimos 6 meses para o LineChart
    final sixMonthsSeries = _buildSixMonthsSeries(transactions, now);

    return FinancialMetrics(
      calculatedAt: now,
      currentBalance: currentBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
      emergencyMonths: emergencyMonths,
      incomeCommitment: incomeCommitment,
      dailyBurnRate: dailyBurnRate,
      monthEndProjection: monthEndProjection,
      healthScore: healthScore,
      sixMonthsSeries: sixMonthsSeries,
    );
  }

  static double _calculateAverageMonthlyExpenseLast3Months(
    List<Transaction> transactions,
    DateTime now, {
    required double currentMonthExpenseFallback,
  }) {
    double sumExpenses = 0.0;
    int monthsWithData = 0;

    for (int i = 0; i < 3; i++) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthExpense = transactions
          .where(
            (t) =>
                t.isExpense &&
                t.date.year == targetDate.year &&
                t.date.month == targetDate.month,
          )
          .fold(0.0, (sum, t) => sum + t.amount);
      if (monthExpense > 0) {
        sumExpenses += monthExpense;
        monthsWithData++;
      }
    }

    if (monthsWithData == 0) {
      return currentMonthExpenseFallback;
    }
    return sumExpenses / monthsWithData;
  }

  static List<MonthlyCashFlowPoint> _buildSixMonthsSeries(
    List<Transaction> transactions,
    DateTime now,
  ) {
    final points = <MonthlyCashFlowPoint>[];
    for (int i = 5; i >= 0; i--) {
      final target = DateTime(now.year, now.month - i, 1);
      final monthTxs = transactions.where(
        (t) => t.date.year == target.year && t.date.month == target.month,
      );
      final income = TransactionCalculations.calculateTotalIncome(monthTxs);
      final expense = TransactionCalculations.calculateTotalExpense(monthTxs);
      points.add(
        MonthlyCashFlowPoint(
          month: target.month,
          year: target.year,
          label: _monthShortNames[target.month - 1],
          income: income,
          expense: expense,
        ),
      );
    }
    return points;
  }
}
