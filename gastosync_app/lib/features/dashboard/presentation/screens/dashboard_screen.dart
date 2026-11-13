import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gastosync_top_header.dart';
import '../../../planning/domain/models/credit_card_model.dart';
import '../../../settings/domain/models/user_profile.dart';
import '../../../transactions/domain/models/bill.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/controllers/transactions_controller.dart';
import '../../../transactions/presentation/widgets/manual_transaction_form_modal.dart';
import '../../domain/services/financial_health_engine.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isBalanceHidden = false;

  String _formatValue(NumberFormat formatter, double value) {
    if (_isBalanceHidden) return 'R\$ ••••••';
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;

    final metricsAsync = ref.watch(financialMetricsStreamProvider);
    final latestInsightAsync = ref.watch(latestAgentInsightStreamProvider);
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final billsAsync = ref.watch(watchBillsProvider);
    final creditCardsAsync = ref.watch(watchCreditCardsProvider);
    final profile = ref.watch(userProfileProvider);

    final metrics = metricsAsync.value ??
        FinancialHealthEngine.calculate(const []);
    final latestInsight = latestInsightAsync.value;
    final transactions = transactionsAsync.value ?? const <Transaction>[];
    final bills =
        (billsAsync.value ?? const <Bill>[]).where((b) => !b.isDeleted).toList();
    final creditCards = (creditCardsAsync.value ?? const <LocalCreditCard>[])
        .map(CreditCard.fromLocal)
        .toList();
    final cardSummaries = CreditCardUsageSummary.calculateAll(
      cards: creditCards,
      transactions: transactions,
      bills: bills,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 28.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              _buildWebPeriodHeader(context),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildHeroBalanceCard(
                      context,
                      currencyFormatter,
                      metrics,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 7,
                    child: _buildMonthSummarySection(
                      context,
                      currencyFormatter,
                      metrics,
                      profile,
                      isDesktop: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildBurnRateCard(
                      context,
                      currencyFormatter,
                      metrics,
                      profile,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildUpcomingBillsCard(
                          context,
                          currencyFormatter,
                          bills,
                        ),
                        const SizedBox(height: 20),
                        _buildCreditCardHealthyLimitCard(
                          context,
                          currencyFormatter,
                          cardSummaries,
                        ),
                        const SizedBox(height: 20),
                        _buildRecentTransactionsAndInsightsCard(
                          context,
                          currencyFormatter,
                          latestInsight,
                          metrics,
                          transactions,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildHeroBalanceCard(
                context,
                currencyFormatter,
                metrics,
              ),
              const SizedBox(height: 22),
              _buildMonthSummarySection(
                context,
                currencyFormatter,
                metrics,
                profile,
                isDesktop: false,
              ),
              const SizedBox(height: 22),
              _buildUpcomingBillsCard(
                context,
                currencyFormatter,
                bills,
              ),
              const SizedBox(height: 22),
              _buildCreditCardHealthyLimitCard(
                context,
                currencyFormatter,
                cardSummaries,
              ),
              const SizedBox(height: 22),
              _buildBurnRateCard(
                context,
                currencyFormatter,
                metrics,
                profile,
              ),
              const SizedBox(height: 22),
              _buildRecentTransactionsAndInsightsCard(
                context,
                currencyFormatter,
                latestInsight,
                metrics,
                transactions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWebPeriodHeader(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    final currentPeriod = '${months[now.month - 1]} ${now.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Visão Geral',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                currentPeriod,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Hero Card escuro `SALDO DISPONÍVEL` (#0F172A) conforme protótipo Figma v2
  Widget _buildHeroBalanceCard(
    BuildContext context,
    NumberFormat formatter,
    FinancialMetrics metrics,
  ) {
    final isPositive = metrics.currentBalance >= 0;

    return Container(
      key: const Key('hero_balance_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.heroNavyCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'SALDO DISPONÍVEL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              InkWell(
                key: const Key('toggle_balance_visibility_button'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() => _isBalanceHidden = !_isBalanceHidden);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isBalanceHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 15,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBalanceHidden ? 'Mostrar' : 'Ocultar',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatValue(formatter, metrics.currentBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPositive
                      ? '+12,4% vs. mês anterior'
                      : 'Atenção ao fluxo negativo',
                  style: const TextStyle(
                    color: AppTheme.emeraldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Patrimônio Líquido: ${_formatValue(formatter, metrics.netWorth)}',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: AppTheme.navyBorder.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroSubMetric(
                  label: 'Renda mensal',
                  value: _formatValue(formatter, metrics.totalIncome),
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppTheme.emeraldPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppTheme.navyBorder.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HeroSubMetric(
                  label: 'Despesas do mês',
                  value: _formatValue(formatter, metrics.totalExpense),
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.navyBorder.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fixos: ${_formatValue(formatter, metrics.fixedExpenses)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Variáveis: ${_formatValue(formatter, metrics.variableExpenses)}',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seção `Resumo do Mês` com Grid 2x2 (`Taxa de Poupança`, `Reserva de Emergência`, `Comprometimento` e `Score Financeiro`)
  Widget _buildMonthSummarySection(
    BuildContext context,
    NumberFormat formatter,
    FinancialMetrics metrics,
    UserProfile profile, {
    required bool isDesktop,
  }) {
    final savingsProgress =
        (metrics.savingsRate / math.max(1.0, profile.savingsRateTarget))
            .clamp(0.0, 1.0);
    final emergencyProgress = (metrics.emergencyMonths / 6.0).clamp(0.0, 1.0);
    final commitmentProgress =
        (metrics.incomeCommitment / 100.0).clamp(0.0, 1.0);
    final scoreProgress = (metrics.healthScore / 100.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Resumo do Mês',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/planning'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.emeraldDeep,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Ver tudo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.85 : 1.08,
          children: [
            _SummaryGridCard(
              title: 'Taxa de Poupança',
              mainValue: '${metrics.savingsRate.toStringAsFixed(1)}%',
              subtitle:
                  'Meta: ${profile.savingsRateTarget.toStringAsFixed(0)}%',
              progress: savingsProgress,
              progressColor: AppTheme.emeraldPrimary,
            ),
            _SummaryGridCard(
              title: 'Reserva de Emergência',
              mainValue: '${metrics.emergencyMonths.toStringAsFixed(1)} meses',
              subtitle: 'Meta: 6 meses cobertos',
              progress: emergencyProgress,
              progressColor: AppTheme.emeraldPrimary,
            ),
            _SummaryGridCard(
              title: 'Comprometimento',
              mainValue: '${metrics.incomeCommitment.toStringAsFixed(1)}%',
              subtitle: 'Meta saudável: < 30% da renda',
              progress: commitmentProgress,
              progressColor: metrics.incomeCommitment > 30
                  ? AppTheme.warningAmber
                  : AppTheme.emeraldPrimary,
            ),
            _SummaryGridCard(
              title: 'Score Financeiro',
              mainValue: '${metrics.healthScore.toStringAsFixed(0)}/100',
              subtitle: metrics.healthScore >= 70
                  ? 'Status: Saudável'
                  : 'Status: Em evolução',
              progress: scoreProgress,
              progressColor: AppTheme.emeraldPrimary,
              badgeText: metrics.healthScore >= 70 ? 'Saudável' : 'Ativo',
            ),
          ],
        ),
      ],
    );
  }

  /// Card `Burn Rate` com alerta amarelo e gráfico `fl_chart` comparando gasto acumulado vs. Teto mensal
  Widget _buildBurnRateCard(
    BuildContext context,
    NumberFormat formatter,
    FinancialMetrics metrics,
    UserProfile profile,
  ) {
    final effectiveIncome = metrics.totalIncome > 0
        ? metrics.totalIncome
        : profile.monthlyBaseIncome;
    final monthlyCeiling =
        effectiveIncome * (1.0 - (profile.savingsRateTarget / 100.0));
    final now = DateTime.now();
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = math.max(1, totalDays - now.day);
    final remainingAllowance =
        math.max(0.0, monthlyCeiling - metrics.totalExpense);
    final suggestedDailyMax = remainingAllowance / remainingDays;

    // Pontos para a curva de evolução do Burn Rate vs. Teto Mensal (fl_chart)
    final currentDay = math.max(1, now.day);
    final accumulatedSpots = <FlSpot>[
      const FlSpot(1, 0),
      FlSpot(
        math.max(2, (currentDay / 2).round()).toDouble(),
        metrics.totalExpense * 0.48,
      ),
      FlSpot(currentDay.toDouble(), metrics.totalExpense),
      FlSpot(totalDays.toDouble(), metrics.monthEndProjection),
    ];

    final ceilingSpots = <FlSpot>[
      FlSpot(1, monthlyCeiling),
      FlSpot(totalDays.toDouble(), monthlyCeiling),
    ];

    final maxY = (math.max(
              monthlyCeiling,
              math.max(metrics.totalExpense, metrics.monthEndProjection),
            ) *
            1.25)
        .clamp(1000.0, double.infinity);
    final interval = (maxY / 4).roundToDouble();

    return Container(
      key: const Key('burn_rate_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Burn Rate Mensal',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Evolução de despesas acumuladas vs. Teto mensal',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: AppTheme.warningBadgeDecoration,
                child: const Text(
                  'Monitoramento Diário',
                  style: TextStyle(
                    color: AppTheme.warningDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Velocidade (R$/dia) e Projeção de Fim de Mês
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Velocidade atual',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatter.format(metrics.dailyBurnRate)}/dia',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Projeção fim do mês',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatter.format(metrics.monthEndProjection),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Banner de alerta amarelo
          Container(
            key: const Key('burn_rate_warning_banner'),
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.warningBannerDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningDark,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mantenha o gasto médio em até ${formatter.format(suggestedDailyMax)}/dia nos próximos $remainingDays dias para respeitar o teto mensal (${formatter.format(monthlyCeiling)}).',
                    style: const TextStyle(
                      color: AppTheme.warningDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legenda do gráfico
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 16,
              runSpacing: 6,
              children: [
                _buildLegendItem('Gasto Acumulado', AppTheme.emeraldPrimary),
                _buildLegendItem('Teto mensal', AppTheme.errorColor),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Gráfico LineChart (fl_chart)
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: AppTheme.cardBorder,
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
                      reservedSize: 46,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        final label = value >= 1000
                            ? '${(value / 1000).toStringAsFixed(1)}k'
                            : value.toInt().toString();
                        return Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt();
                        if (day < 1 || day > totalDays) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            'Dia $day',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: totalDays.toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Linha verde de gasto acumulado
                  LineChartBarData(
                    spots: accumulatedSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.emeraldPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.emeraldPrimary.withValues(alpha: 0.22),
                          AppTheme.emeraldPrimary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Linha pontilhada vermelha do Teto Mensal
                  LineChartBarData(
                    spots: ceilingSpots,
                    isCurved: false,
                    color: AppTheme.errorColor,
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
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
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Card `Últimas Transações & Insights` (T042): Banner cinza de insight da IA + últimas 4 transações com status
  Widget _buildRecentTransactionsAndInsightsCard(
    BuildContext context,
    NumberFormat formatter,
    LocalAgentInsight? latestInsight,
    FinancialMetrics metrics,
    List<Transaction> transactions,
  ) {
    final tipText = latestInsight != null
        ? '[Categoria: ${latestInsight.categorySuggested} • Confiança ${(latestInsight.confidenceScore * 100).round()}%] ${latestInsight.budgetTip}'
        : 'Sua reserva de emergência atual cobre ${metrics.emergencyMonths.toStringAsFixed(1)} meses de despesas e seu Score Financeiro está em ${metrics.healthScore.toStringAsFixed(0)}/100.';

    final recentFour = transactions.take(4).toList();
    final dateFmt = DateFormat('dd/MM');

    return Container(
      key: const Key('recent_transactions_and_insights_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Últimas Transações & Insights',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/transactions'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emeraldDeep,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Banner cinza de insight da IA
          Container(
            key: const Key('dynamic_agent_insight_card'),
            padding: const EdgeInsets.all(14.0),
            decoration: AppTheme.subtleInsightBannerDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GastoSyncAiBadge(size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Insight do Agente Preditivo (IA)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tipText,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista das últimas 4 transações
          if (recentFour.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 36,
                      color: AppTheme.textMuted,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nenhuma transação registrada ainda',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Use o botão verde + para adicionar uma receita ou despesa local.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: recentFour.length,
              separatorBuilder: (_, _) => const Divider(
                color: AppTheme.cardBorder,
                height: 20,
              ),
              itemBuilder: (context, index) {
                final tx = recentFour[index];
                final isIncome = tx.isIncome;
                final iconData = _categoryIcon(tx.category, isIncome: isIncome);

                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isIncome
                            ? AppTheme.emeraldSoftBg
                            : AppTheme.subtleSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconData,
                        size: 20,
                        color: isIncome
                            ? AppTheme.emeraldDeep
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tx.category} · ${dateFmt.format(tx.date)}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? "+" : "-"} ${_formatValue(formatter, tx.amount)}',
                          style: TextStyle(
                            color: isIncome
                                ? AppTheme.emeraldDeep
                                : AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: tx.isSynced
                              ? AppTheme.emeraldBadgeDecoration
                              : AppTheme.warningBadgeDecoration,
                          child: Text(
                            tx.isSynced ? 'Sincronizado' : 'Pendente local',
                            style: TextStyle(
                              color: tx.isSynced
                                  ? AppTheme.emeraldDeep
                                  : AppTheme.warningDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// Card compacto "Próximos Boletos & Vencimentos" com navegação rápida para Boletos a Pagar (T017)
  Widget _buildUpcomingBillsCard(
    BuildContext context,
    NumberFormat formatter,
    List<Bill> bills,
  ) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final unpaidBills = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final upcomingThree = unpaidBills.take(3).toList();

    final totalRealToPay =
        BillCalculations.calculateTotalPendingCashOutflow(bills);
    final totalCardCharges =
        BillCalculations.calculateTotalCreditCardCharges(bills);
    final overdueCount = unpaidBills.where((b) => b.isOverdue()).length;
    final dueTodayCount = unpaidBills.where((b) => b.isDueToday()).length;

    void navigateToBillsView() {
      ref.read(selectedTransactionsSubTabProvider.notifier).selectSubTab(1);
      context.go('/transactions');
    }

    return Container(
      key: const Key('dashboard_upcoming_bills_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: overdueCount > 0 || dueTodayCount > 0
                      ? AppTheme.warningBadgeBg
                      : AppTheme.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: overdueCount > 0 || dueTodayCount > 0
                      ? AppTheme.warningDark
                      : AppTheme.emeraldDeep,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Próximos Boletos & Vencimentos',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const Key('dashboard_view_all_bills_button'),
                onPressed: navigateToBillsView,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emeraldDeep,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Ver boletos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Resumo compacto: Total Real a Pagar vs. Lembretes no Cartão (FR-011b)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Real a Pagar',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatValue(formatter, totalRealToPay),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppTheme.cardBorder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inclusos na Fatura',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatValue(formatter, totalCardCharges),
                        style: const TextStyle(
                          color: AppTheme.emeraldDeep,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('dashboard_add_bill_button'),
                  tooltip: 'Novo boleto / conta',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ManualTransactionFormModal.show(
                    context,
                    startInBillMode: true,
                  ),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppTheme.emeraldDeep,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (upcomingThree.isEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ManualTransactionFormModal.show(
                context,
                startInBillMode: true,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: AppTheme.emeraldPrimary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nenhum boleto pendente. Toque para agendar conta ou boleto recorrente.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: upcomingThree.length,
              separatorBuilder: (_, _) => const Divider(
                color: AppTheme.cardBorder,
                height: 18,
              ),
              itemBuilder: (context, index) {
                final bill = upcomingThree[index];
                final isOverdue = bill.isOverdue();
                final isDueToday = bill.isDueToday();
                final daysUntil = bill.daysUntilDue();

                final String badgeText;
                final Color badgeColor;
                final Color badgeBg;

                if (isOverdue) {
                  badgeText = 'Vencido (${daysUntil.abs()}d)';
                  badgeColor = AppTheme.errorColor;
                  badgeBg = AppTheme.errorColor.withValues(alpha: 0.12);
                } else if (isDueToday) {
                  badgeText = 'Vence hoje';
                  badgeColor = AppTheme.warningDark;
                  badgeBg = AppTheme.warningBadgeBg;
                } else {
                  badgeText =
                      daysUntil <= 3 ? 'Vence em ${daysUntil}d' : dateFmt.format(bill.dueDate);
                  badgeColor = AppTheme.textSecondary;
                  badgeBg = AppTheme.subtleSurface;
                }

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: navigateToBillsView,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: bill.isCreditCardCharge
                              ? AppTheme.emeraldSoftBg
                              : AppTheme.subtleSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          bill.isCreditCardCharge
                              ? Icons.credit_card_rounded
                              : _categoryIcon(bill.category, isIncome: false),
                          size: 18,
                          color: bill.isCreditCardCharge
                              ? AppTheme.emeraldDeep
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${bill.category}${bill.isCreditCardCharge ? " · Cartão" : ""} · ${dateFmt.format(bill.dueDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatValue(formatter, bill.amount),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Card de Indicador Resumido de Cartões & Limite Saudável (50%–80%) no Dashboard (T031 / US5)
  Widget _buildCreditCardHealthyLimitCard(
    BuildContext context,
    NumberFormat formatter,
    List<CreditCardUsageSummary> cardSummaries,
  ) {
    if (cardSummaries.isEmpty) return const SizedBox.shrink();

    final totalLimit = cardSummaries.fold<double>(
      0.0,
      (sum, item) => sum + item.card.limitAmount,
    );
    final totalUsed = cardSummaries.fold<double>(
      0.0,
      (sum, item) => sum + item.totalUsedAmount,
    );
    final totalAvailable = math.max(0.0, totalLimit - totalUsed);
    final overallPercent =
        totalLimit > 0 ? (totalUsed / totalLimit) * 100.0 : 0.0;
    final hasAlert = cardSummaries.any((s) => s.isAboveHealthyCeiling);

    return Container(
      key: const Key('dashboard_credit_cards_limit_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasAlert
                      ? AppTheme.warningBadgeBg
                      : AppTheme.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  size: 18,
                  color:
                      hasAlert ? AppTheme.warningDark : AppTheme.emeraldDeep,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cartões & Limite Saudável',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const Key('dashboard_manage_credit_cards_button'),
                onPressed: () => context.go('/planning'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emeraldDeep,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Gerenciar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Faixa de resumo global dos cartões
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Utilizado no Mês',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatValue(formatter, totalUsed)} (${overallPercent.round()}%)',
                        style: TextStyle(
                          color: hasAlert
                              ? AppTheme.errorColor
                              : AppTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppTheme.cardBorder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Limite Livre',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatValue(formatter, totalAvailable),
                        style: const TextStyle(
                          color: AppTheme.emeraldDeep,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista compacta de cartões monitorados e faixa saudável (50%–80%)
          ...cardSummaries.take(3).map((summary) {
            final card = summary.card;
            final ratio =
                (summary.utilizationPercent / 100.0).clamp(0.0, 1.0);
            final Color barColor;
            if (summary.isLimitExceeded) {
              barColor = AppTheme.errorColor;
            } else if (summary.isAboveHealthyCeiling) {
              barColor = AppTheme.warningAmber;
            } else {
              barColor = AppTheme.emeraldPrimary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${card.name} · Faixa ${card.targetMinPercent.round()}%–${card.targetMaxPercent.round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${summary.utilizationPercent.round()}% · Teto ${_formatValue(formatter, card.healthyMaxAmount)}',
                        style: TextStyle(
                          color: summary.isAboveHealthyCeiling
                              ? AppTheme.errorColor
                              : AppTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppTheme.subtleSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category, {required bool isIncome}) {
    if (isIncome) return Icons.payments_outlined;
    final lower = category.toLowerCase();
    if (lower.contains('aliment')) return Icons.restaurant_rounded;
    if (lower.contains('moradia')) return Icons.home_work_outlined;
    if (lower.contains('transp')) return Icons.directions_car_outlined;
    if (lower.contains('lazer')) return Icons.movie_outlined;
    if (lower.contains('saúde') || lower.contains('saude')) {
      return Icons.favorite_border_rounded;
    }
    return Icons.receipt_long_outlined;
  }
}

class _HeroSubMetric extends StatelessWidget {
  const _HeroSubMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryGridCard extends StatelessWidget {
  const _SummaryGridCard({
    required this.title,
    required this.mainValue,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
    this.badgeText,
  });

  final String title;
  final String mainValue;
  final String subtitle;
  final double progress;
  final Color progressColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: AppTheme.emeraldBadgeDecoration,
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      color: AppTheme.emeraldDeep,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            mainValue,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppTheme.subtleSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
