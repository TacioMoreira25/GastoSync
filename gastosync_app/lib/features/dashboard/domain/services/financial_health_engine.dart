import 'dart:math' as math;
import 'package:drift/drift.dart' show Value;
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
    this.fixedExpenses = 0.0,
    this.variableExpenses = 0.0,
    this.hasTransactions = true,
    this.usedBaseIncomeFallback = false,
    this.emergencyReferenceCost = 0.0,
    this.emergencyReferenceSource = 'custo projetado',
    double? netWorth,
  }) : netWorth = netWorth ?? currentBalance;

  final DateTime calculatedAt;

  /// 1. Renda Mensal Total
  final double totalIncome;

  /// 2. Despesas do Mês
  final double totalExpense;

  /// 3. Saldo Atual
  final double currentBalance;

  /// 4. Taxa de Poupança (%)
  final double savingsRate;

  /// 5. Gastos Fixos do Mês
  final double fixedExpenses;

  /// 6. Gastos Variáveis do Mês
  final double variableExpenses;

  /// 7. Comprometimento de Renda (% — referência saudável < 30%)
  final double incomeCommitment;

  /// 8. Reserva de Emergência (em meses) e seu custo de referência
  final double emergencyMonths;
  final double emergencyReferenceCost;
  final String emergencyReferenceSource;

  /// 9. Patrimônio Líquido (Saldo acumulado + ativos/investimentos)
  final double netWorth;

  /// Agente Orçamentário (Burn Rate Diário e Projeção de Fim de Mês)
  final double dailyBurnRate;
  final double monthEndProjection;
  final double healthScore;
  final List<MonthlyCashFlowPoint> sixMonthsSeries;
  final bool hasTransactions;
  final bool usedBaseIncomeFallback;

  /// Score inteiro consolidado (0 quando não há movimentações)
  int get roundedScore => hasTransactions ? healthScore.round().clamp(0, 100) : 0;

  /// Rótulo padronizado do Score Financeiro em todo o aplicativo
  String get scoreStatusLabel {
    if (!hasTransactions) return 'Sem dados';
    final s = roundedScore;
    if (s >= 60) return 'Saudável';
    if (s >= 40) return 'Atenção';
    return 'Crítico';
  }

  bool get isScoreHealthy => hasTransactions && roundedScore >= 60;
  bool get isScoreWarning =>
      hasTransactions && roundedScore >= 40 && roundedScore < 60;
  bool get isScoreCritical => hasTransactions && roundedScore < 40;

  /// Indica se o comprometimento de renda respeita a diretriz saudável (< 30%)
  bool get isCommitmentWithin30Percent => incomeCommitment <= 30.0;

  /// Rótulo amigável para a Reserva de Emergência (padrão brasileiro com vírgula)
  String get formattedEmergencyMonths {
    if (!hasTransactions || currentBalance <= 0 || emergencyMonths <= 0) {
      return '0,0 meses';
    }
    if (emergencyMonths > 24.0) return '24+ meses';
    return '${emergencyMonths.toStringAsFixed(1).replaceAll('.', ',')} meses';
  }

  /// Badge de status da Reserva de Emergência para o Dashboard
  String get emergencyStatusBadgeLabel {
    if (!hasTransactions || emergencyMonths <= 0) return 'Sem cobertura';
    if (emergencyMonths >= 6.0) return 'Meta 6 meses';
    return 'Em construção';
  }

  /// Projeção inteligente de fim de mês separando gastos fixos (1x/mês) + boletos pendentes do mês
  /// da extrapolação diária apenas dos gastos variáveis.
  double realisticMonthEndProjection({
    double pendingMonthCashBills = 0.0,
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? calculatedAt;
    final elapsedDays = math.max(1, ref.day);
    final totalDaysInMonth = DateTime(ref.year, ref.month + 1, 0).day;
    final remainingDays = math.max(0, totalDaysInMonth - elapsedDays);
    final variableDailyRate = variableExpenses / elapsedDays;
    final projectedVariable =
        variableExpenses + (variableDailyRate * remainingDays);
    return fixedExpenses + projectedVariable + math.max(0.0, pendingMonthCashBills);
  }

  LocalMetricsCompanion toCompanion({String? userEmail}) {
    final normalizedEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : null;
    return LocalMetricsCompanion.insert(
      userEmail: normalizedEmail != null
          ? Value(normalizedEmail)
          : const Value.absent(),
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

/// Calculadora adaptativa em 3 camadas para a Reserva de Emergência:
/// 1. Média real das despesas mensais fechadas dos últimos 3 meses (`averagePastThreeMonths`);
/// 2. Projeção de fechamento do mês corrente via Burn Rate (`projectedExpenses`);
/// 3. Piso estrutural de gastos fixos (`fixedExpenses`).
class EmergencyFundCalculator {
  const EmergencyFundCalculator._();

  /// Calcula os meses de cobertura da reserva de emergência
  static double calculateEmergencyMonths({
    required double netWorth,
    required double currentExpenses,
    required double projectedExpenses,
    required double fixedExpenses,
    double? averagePastThreeMonths,
  }) {
    if (netWorth <= 0) return 0.0;

    // 1. Prioridade: Média histórica consolidada (se houver histórico fechado)
    if (averagePastThreeMonths != null && averagePastThreeMonths > 0) {
      return netWorth / averagePastThreeMonths;
    }

    // 2. Fallback Preditivo: Projeção de fechamento do mês via Burn Rate
    if (projectedExpenses > 0) {
      return netWorth / projectedExpenses;
    }

    // 3. Fallback Mínimo: Gastos fixos estruturais
    if (fixedExpenses > 0) {
      return netWorth / fixedExpenses;
    }

    // Evita divisão por zero caso o usuário não tenha cadastrado despesas
    return 0.0;
  }

  /// Identifica o custo mensal de referência utilizado na cascata e o rótulo explicativo para a UI
  static ({double referenceCost, String sourceLabel}) resolveReferenceCost({
    required double projectedExpenses,
    required double fixedExpenses,
    double? averagePastThreeMonths,
  }) {
    if (averagePastThreeMonths != null && averagePastThreeMonths > 0) {
      return (
        referenceCost: averagePastThreeMonths,
        sourceLabel: 'média histórica',
      );
    }
    if (projectedExpenses > 0) {
      return (
        referenceCost: projectedExpenses,
        sourceLabel: 'custo projetado',
      );
    }
    if (fixedExpenses > 0) {
      return (
        referenceCost: fixedExpenses,
        sourceLabel: 'gastos fixos',
      );
    }
    return (referenceCost: 0.0, sourceLabel: 'sem despesas');
  }
}

/// Motor Contábil e Agente Orçamentário em Dart para cálculo determinístico e 100% local
/// dos 9 Indicadores Financeiros + Burn Rate (T029)
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

  static bool _isFixedExpense(Transaction tx) {
    if (!tx.isExpense) return false;
    final cat = tx.category.trim().toLowerCase();
    final desc = tx.description.trim().toLowerCase();

    if (cat == 'moradia' ||
        cat == 'educação' ||
        cat == 'educacao' ||
        cat == 'assinaturas' ||
        cat == 'gastos fixos' ||
        cat == 'fixo') {
      return true;
    }

    const fixedKeywords = <String>[
      'aluguel',
      'condomínio',
      'condominio',
      'internet',
      'luz',
      'energia',
      'água',
      'agua',
      'gás',
      'gas',
      'mensalidade',
      'faculdade',
      'escola',
      'plano de saúde',
      'plano de saude',
      'seguro',
      'financiamento',
      'assinatura',
      'netflix',
      'spotify',
      'academia',
    ];

    for (final keyword in fixedKeywords) {
      if (desc.contains(keyword)) return true;
    }
    return false;
  }

  static bool _isInvestmentAllocation(Transaction tx) {
    final cat = tx.category.trim().toLowerCase();
    final desc = tx.description.trim().toLowerCase();
    return cat.contains('invest') ||
        cat.contains('reserva') ||
        cat.contains('poupan') ||
        desc.contains('tesouro') ||
        desc.contains('cdb') ||
        desc.contains('reserva');
  }

  static FinancialMetrics calculate(
    List<Transaction> transactions, {
    DateTime? referenceDate,
    double monthlyBaseIncome = 0.0,
  }) {
    final now = referenceDate ?? DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final hasTransactions = transactions.isNotEmpty;

    // 3. Saldo Atual (Líquido Acumulado) = sum(Receitas) - sum(Despesas)
    final currentBalance =
        TransactionCalculations.calculateNetBalance(transactions);

    // Filtra transações do mês vigente
    final currentMonthTxs = transactions
        .where((t) => t.date.year == currentYear && t.date.month == currentMonth)
        .toList();

    // 1. Renda Mensal Total (Receitas lançadas no mês)
    final totalIncome =
        TransactionCalculations.calculateTotalIncome(currentMonthTxs);

    // 2. Despesas do Mês
    final totalExpense =
        TransactionCalculations.calculateTotalExpense(currentMonthTxs);

    final safeBaseIncome = math.max(0.0, monthlyBaseIncome);
    final usedBaseIncomeFallback =
        hasTransactions && totalIncome <= 0 && safeBaseIncome > 0;
    final effectiveIncome =
        totalIncome > 0 ? totalIncome : safeBaseIncome;

    // 4. Taxa de Poupança (%) = (Renda Efetiva - Despesa Mensal) / Renda Efetiva * 100
    final double savingsRate = (hasTransactions && effectiveIncome > 0)
        ? ((effectiveIncome - totalExpense) / effectiveIncome) * 100.0
        : 0.0;

    // 5. Gastos Fixos & 6. Gastos Variáveis
    final double fixedExpenses = currentMonthTxs
        .where(_isFixedExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final double variableExpenses =
        math.max(0.0, totalExpense - fixedExpenses);

    // 7. Comprometimento da Renda (%) = Despesa Mensal / Renda Efetiva * 100 (Referência < 30%)
    final double incomeCommitment = !hasTransactions
        ? 0.0
        : (effectiveIncome > 0
            ? (totalExpense / effectiveIncome) * 100.0
            : (totalExpense > 0 ? 100.0 : 0.0));

    // 9. Patrimônio Líquido = Saldo Atual + aportes em Investimentos registrados como saída
    final double investedAllocations = transactions
        .where((t) => t.isExpense && _isInvestmentAllocation(t))
        .fold(0.0, (sum, t) => sum + t.amount);
    final double netWorth = currentBalance + investedAllocations;

    // Agente Orçamentário: Burn Rate Diário = Despesa Total do Mês / Dias Transcorridos do Mês Atual
    final elapsedDays = math.max(1, now.day);
    final dailyBurnRate = totalExpense / elapsedDays;

    // Projeção de Fim de Mês = Despesa Atual + (Burn Rate Diário * Dias Restantes do Mês)
    final totalDaysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final remainingDays = math.max(0, totalDaysInMonth - elapsedDays);
    final monthEndProjection = totalExpense + (dailyBurnRate * remainingDays);

    // 8. Reserva de Emergência em Meses via EmergencyFundCalculator (cascata de 3 níveis):
    // Nível 1: Média real dos últimos 3 meses fechados (i = 1..3)
    // Nível 2: Projeção de fechamento do mês corrente via Burn Rate (monthEndProjection)
    // Nível 3: Piso estrutural de gastos fixos (fixedExpenses)
    final closedAvg3Months = _calculateClosedAverageMonthlyExpenseLast3Months(
      transactions,
      now,
    );
    final resolvedRef = EmergencyFundCalculator.resolveReferenceCost(
      projectedExpenses: monthEndProjection,
      fixedExpenses: fixedExpenses,
      averagePastThreeMonths: closedAvg3Months,
    );
    final double emergencyMonths =
        EmergencyFundCalculator.calculateEmergencyMonths(
      netWorth: netWorth,
      currentExpenses: totalExpense,
      projectedExpenses: monthEndProjection,
      fixedExpenses: fixedExpenses,
      averagePastThreeMonths: closedAvg3Months,
    );

    // Score de Saúde Financeira (0-100):
    // Score = (Poupança * 0.3) + (min(Reserva em Meses / 6, 1) * 35) + ((1 - min(ComprometimentoRatio, 1)) * 35)
    final clampedSavings = savingsRate.clamp(0.0, 100.0);
    final reserveFactor = math.min(emergencyMonths / 6.0, 1.0).clamp(0.0, 1.0);
    final commitmentRatio = (incomeCommitment / 100.0).clamp(0.0, 1.0);
    final double commitmentScore =
        effectiveIncome > 0 ? ((1.0 - commitmentRatio) * 35.0) : 0.0;
    final double rawScore = !hasTransactions
        ? 0.0
        : (clampedSavings * 0.3) + (reserveFactor * 35.0) + commitmentScore;
    final healthScore = rawScore.clamp(0.0, 100.0);

    // Série histórica dos últimos 6 meses para o LineChart
    final sixMonthsSeries = _buildSixMonthsSeries(transactions, now);

    return FinancialMetrics(
      calculatedAt: now,
      currentBalance: currentBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
      fixedExpenses: fixedExpenses,
      variableExpenses: variableExpenses,
      emergencyMonths: emergencyMonths,
      emergencyReferenceCost: resolvedRef.referenceCost,
      emergencyReferenceSource: resolvedRef.sourceLabel,
      incomeCommitment: incomeCommitment,
      netWorth: netWorth,
      dailyBurnRate: dailyBurnRate,
      monthEndProjection: monthEndProjection,
      healthScore: healthScore,
      sixMonthsSeries: sixMonthsSeries,
      hasTransactions: hasTransactions,
      usedBaseIncomeFallback: usedBaseIncomeFallback,
    );
  }

  /// Calcula a média mensal de despesas considerando APENAS os últimos 3 meses fechados
  /// (i = 1, 2, 3), nunca misturando o mês corrente parcial em aberto.
  static double? _calculateClosedAverageMonthlyExpenseLast3Months(
    List<Transaction> transactions,
    DateTime now,
  ) {
    double sumExpenses = 0.0;
    int monthsWithData = 0;

    for (int i = 1; i <= 3; i++) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthExpense = transactions
          .where(
            (t) =>
                t.isExpense &&
                !t.isDeleted &&
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
      return null;
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
