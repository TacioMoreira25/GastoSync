import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../transactions/presentation/widgets/manual_transaction_form_modal.dart';
import '../../domain/services/financial_health_engine.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/quick_expense_input_field.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    final metricsAsync = ref.watch(financialMetricsStreamProvider);
    final latestInsightAsync = ref.watch(latestAgentInsightStreamProvider);

    final metrics = metricsAsync.valueOrNull ??
        FinancialHealthEngine.calculate(const []);
    final latestInsight = latestInsightAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Novo Lançamento Manual',
            onPressed: () => ManualTransactionFormModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notificações',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(context),
            const SizedBox(height: 18),
            const QuickExpenseInputField(),
            const SizedBox(height: 24),
            _buildMetricCardsGrid(
              context,
              currencyFormatter,
              screenWidth,
              metrics,
            ),
            const SizedBox(height: 28),
            _buildChartCard(context, metrics.sixMonthsSeries),
            const SizedBox(height: 28),
            _buildAgentInsightCard(context, latestInsight, metrics),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá, Investidor!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'As 9 métricas canônicas de saúde financeira calculadas 100% localmente em tempo real.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCardsGrid(
    BuildContext context,
    NumberFormat formatter,
    double screenWidth,
    FinancialMetrics metrics,
  ) {
    final cards = [
      // 1. Saldo Líquido
      _MetricData(
        title: '1. Saldo Líquido',
        value: formatter.format(metrics.currentBalance),
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF0F766E),
        growthIndicator: metrics.currentBalance >= 0
            ? 'Patrimônio positivo'
            : 'Atenção: saldo negativo',
        isPositiveGrowth: metrics.currentBalance >= 0,
      ),
      // 2. Receita Mensal Total
      _MetricData(
        title: '2. Receitas (Mês)',
        value: formatter.format(metrics.totalIncome),
        icon: Icons.arrow_upward_rounded,
        color: const Color(0xFF16A34A),
        growthIndicator: 'Entradas acumuladas no mês',
        isPositiveGrowth: true,
      ),
      // 3. Despesa Mensal Total
      _MetricData(
        title: '3. Despesas (Mês)',
        value: formatter.format(metrics.totalExpense),
        icon: Icons.arrow_downward_rounded,
        color: const Color(0xFFDC2626),
        growthIndicator: 'Saídas acumuladas no mês',
        isPositiveGrowth: metrics.totalExpense <= metrics.totalIncome,
      ),
      // 4. Taxa de Poupança (%)
      _MetricData(
        title: '4. Taxa de Poupança',
        value: '${metrics.savingsRate.toStringAsFixed(1)}%',
        icon: Icons.savings_rounded,
        color: const Color(0xFF0284C7),
        growthIndicator: 'Meta recomendada: ≥ 20.0%',
        isPositiveGrowth: metrics.savingsRate >= 20.0,
      ),
      // 5. Reserva de Emergência em Meses
      _MetricData(
        title: '5. Reserva em Meses',
        value: '${metrics.emergencyMonths.toStringAsFixed(1)} meses',
        icon: Icons.shield_rounded,
        color: const Color(0xFF8B5CF6),
        growthIndicator: 'Meta: 6 meses de gastos',
        isPositiveGrowth: metrics.emergencyMonths >= 6.0,
      ),
      // 6. Comprometimento da Renda (%)
      _MetricData(
        title: '6. Comprometimento Renda',
        value: '${metrics.incomeCommitment.toStringAsFixed(1)}%',
        icon: Icons.pie_chart_outline_rounded,
        color: const Color(0xFFF59E0B),
        growthIndicator: 'Limite saudável: ≤ 80.0%',
        isPositiveGrowth: metrics.incomeCommitment <= 80.0,
      ),
      // 7. Burn Rate Diário
      _MetricData(
        title: '7. Burn Rate Diário',
        value: '${formatter.format(metrics.dailyBurnRate)}/dia',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFEA580C),
        growthIndicator: 'Velocidade média de gasto',
        isPositiveGrowth:
            metrics.totalIncome == 0 ||
            (metrics.dailyBurnRate * 30) <= metrics.totalIncome,
      ),
      // 8. Projeção de Fim de Mês
      _MetricData(
        title: '8. Projeção Fim de Mês',
        value: formatter.format(metrics.monthEndProjection),
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF4F46E5),
        growthIndicator: metrics.monthEndProjection <= metrics.totalIncome
            ? 'Dentro da receita mensal'
            : 'Acima da receita mensal',
        isPositiveGrowth: metrics.monthEndProjection <= metrics.totalIncome,
      ),
      // 9. Score de Saúde Financeira (0-100)
      _MetricData(
        title: '9. Score Saúde Financeira',
        value: '${metrics.healthScore.toStringAsFixed(0)} / 100',
        icon: Icons.favorite_rounded,
        color: const Color(0xFF10B981),
        growthIndicator: metrics.healthScore >= 70
            ? 'Saúde Financeira Excelente'
            : (metrics.healthScore >= 40 ? 'Estável • Em evolução' : 'Requer atenção'),
        isPositiveGrowth: metrics.healthScore >= 50,
      ),
    ];

    int crossAxisCount = 1;
    if (screenWidth >= 1200) {
      crossAxisCount = 3;
    } else if (screenWidth >= 600) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 140,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return _MetricCard(data: item);
      },
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    List<MonthlyCashFlowPoint> series,
  ) {
    final theme = Theme.of(context);
    double maxVal = 1000.0;
    for (final pt in series) {
      maxVal = math.max(maxVal, math.max(pt.income, pt.expense));
    }
    final maxY = (maxVal * 1.25).ceilToDouble();
    final interval = math.max(200.0, (maxY / 4).roundToDouble());

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), series[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), series[i].expense));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fluxo de Caixa Mensal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receitas vs Despesas (Últimos 6 meses - Dados Reais Drift)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    _buildLegendItem(
                      context,
                      'Receita',
                      theme.colorScheme.primary,
                    ),
                    _buildLegendItem(
                      context,
                      'Despesa',
                      theme.colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          final label = value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toInt().toString();
                          return Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < series.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                series[index].label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: math.max(0, series.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: incomeSpots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.25),
                            theme.colorScheme.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: expenseSpots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: theme.colorScheme.error,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.error.withValues(alpha: 0.15),
                            theme.colorScheme.error.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentInsightCard(
    BuildContext context,
    LocalAgentInsight? latestInsight,
    FinancialMetrics metrics,
  ) {
    final theme = Theme.of(context);
    final tipText = latestInsight != null
        ? '[Categoria: ${latestInsight.categorySuggested} • Confiança ${(latestInsight.confidenceScore * 100).round()}%] ${latestInsight.budgetTip}'
        : 'Sua reserva de emergência atual cobre ${metrics.emergencyMonths.toStringAsFixed(1)} meses de despesas e seu Score de Saúde Financeira está em ${metrics.healthScore.toStringAsFixed(0)}/100. Utilize o campo rápido acima para obter dicas personalizadas do Llama 3.3.';

    return Container(
      key: const Key('dynamic_agent_insight_card'),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insight do Agente Preditivo (IA)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tipText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.9,
                    ),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.growthIndicator,
    required this.isPositiveGrowth,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String growthIndicator;
  final bool isPositiveGrowth;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, size: 18, color: data.color),
                ),
              ],
            ),
            Text(
              data.value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              data.growthIndicator,
              style: theme.textTheme.labelSmall?.copyWith(
                color: data.isPositiveGrowth
                    ? const Color(0xFF16A34A)
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
