import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/domain/services/financial_health_engine.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../settings/domain/models/user_profile.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/controllers/transactions_controller.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  int _selectedSubTab = 0; // 0 = Orçamentos & Metas, 1 = Saúde Financeira

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(watchBudgetsProvider);
    final deletedCategoriesAsync = ref.watch(watchDeletedBudgetCategoriesProvider);
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final metricsAsync = ref.watch(financialMetricsStreamProvider);
    final profile = ref.watch(userProfileProvider);

    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    final transactions = transactionsAsync.value ?? const <Transaction>[];
    final metrics =
        metricsAsync.value ?? FinancialHealthEngine.calculate(transactions);
    final budgets = budgetsAsync.value ?? const <LocalBudget>[];
    final deletedCategories = deletedCategoriesAsync.value ?? const <String>{};

    final displayScore = transactions.isEmpty
        ? 82
        : metrics.healthScore.round().clamp(0, 100);
    final isHealthy = transactions.isEmpty || displayScore >= 60;
    final scoreStatusLabel = isHealthy ? 'Saudável' : 'Atenção';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 28.0 : 16.0,
          isDesktop ? 24.0 : 16.0,
          isDesktop ? 28.0 : 16.0,
          96.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cabeçalho PLANEJAMENTO + Badge "Score XX · Saudável"
            _buildHeader(
              score: displayScore,
              statusLabel: scoreStatusLabel,
              isHealthy: isHealthy,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 16),

            // 2. Seletor de sub-abas ("Orçamentos & Metas" | "Saúde Financeira")
            _buildSubTabSelector(),
            const SizedBox(height: 18),

            if (_selectedSubTab == 0) ...[
              // 3. Botão largo "+ Nova Categoria / Meta"
              _buildNewCategoryGoalButton(context),
              const SizedBox(height: 18),

              // 4. Cards de progresso por categoria
              _buildCategoryBudgetCards(
                context: context,
                budgets: budgets,
                deletedCategories: deletedCategories,
                transactions: transactions,
                currencyFormatter: currencyFormatter,
                isDesktop: isDesktop,
              ),
            ] else ...[
              // Sub-aba "Saúde Financeira": Indicadores detalhados das 9 métricas
              _buildFinancialHealthSubTab(
                metrics: metrics,
                profile: profile,
                displayScore: displayScore,
                statusLabel: scoreStatusLabel,
                currencyFormatter: currencyFormatter,
                isDesktop: isDesktop,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required int score,
    required String statusLabel,
    required bool isHealthy,
    required bool isDesktop,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PLANEJAMENTO',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _selectedSubTab == 0
                    ? 'Orçamentos & Metas'
                    : 'Saúde Financeira',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isDesktop ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          key: const Key('planning_health_score_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: isHealthy
              ? AppTheme.emeraldBadgeDecoration
              : AppTheme.warningBadgeDecoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHealthy
                    ? Icons.verified_rounded
                    : Icons.warning_amber_rounded,
                size: 14,
                color:
                    isHealthy ? AppTheme.emeraldDeep : AppTheme.warningDark,
              ),
              const SizedBox(width: 6),
              Text(
                'Score $score · $statusLabel',
                style: TextStyle(
                  color:
                      isHealthy ? AppTheme.emeraldDeep : AppTheme.warningDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabSelector() {
    return Container(
      key: const Key('planning_subtab_selector'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SubTabButton(
              key: const Key('planning_tab_budgets'),
              label: 'Orçamentos & Metas',
              icon: Icons.pie_chart_outline_rounded,
              isSelected: _selectedSubTab == 0,
              onTap: () => setState(() => _selectedSubTab = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SubTabButton(
              key: const Key('planning_tab_health'),
              label: 'Saúde Financeira',
              icon: Icons.insights_rounded,
              isSelected: _selectedSubTab == 1,
              onTap: () => setState(() => _selectedSubTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewCategoryGoalButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('planning_new_category_goal_button'),
        onPressed: () => _showUpsertBudgetDialog(context),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('+ Nova Categoria / Meta'),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.emeraldPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetCards({
    required BuildContext context,
    required List<LocalBudget> budgets,
    required Set<String> deletedCategories,
    required List<Transaction> transactions,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
  }) {
    final now = DateTime.now();

    // Soma despesas do mês atual por categoria (case-insensitive)
    final spentByCategory = <String, double>{};
    for (final tx in transactions) {
      if (tx.isExpense &&
          tx.date.year == now.year &&
          tx.date.month == now.month) {
        final key = tx.category.trim().toLowerCase();
        spentByCategory[key] = (spentByCategory[key] ?? 0.0) + tx.amount;
      }
    }

    // Mescla metas de LocalBudgets com categorias criadas nas Transações que não foram excluídas
    final mergedByCategory = <String, LocalBudget>{
      for (final b in budgets) b.category.trim().toLowerCase(): b,
    };

    var syntheticTxId = -1000;
    for (final tx in transactions) {
      final rawCat = tx.category.trim();
      final key = rawCat.toLowerCase();
      if (rawCat.isNotEmpty &&
          key != 'renda' &&
          !mergedByCategory.containsKey(key) &&
          !deletedCategories.contains(key)) {
        mergedByCategory[key] = LocalBudget(
          id: syntheticTxId--,
          category: rawCat,
          limitAmount: math.max(spentByCategory[key] ?? 0.0, 500.0),
          month: now.month,
          year: now.year,
        );
      }
    }

    final effectiveBudgets = mergedByCategory.values.toList();

    if (effectiveBudgets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: const Center(
          child: Text(
            'Nenhuma meta configurada. Adicione uma categoria acima.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final cards = effectiveBudgets.map((budget) {
      final spent =
          spentByCategory[budget.category.trim().toLowerCase()] ?? 0.0;
      return _buildSingleBudgetCard(
        context: context,
        budget: budget,
        spent: spent,
        currencyFormatter: currencyFormatter,
      );
    }).toList();

    if (isDesktop && cards.length > 1) {
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += 2) {
        final hasSecond = i + 1 < cards.length;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 16),
                Expanded(
                  child: hasSecond ? cards[i + 1] : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Column(children: rows);
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSingleBudgetCard({
    required BuildContext context,
    required LocalBudget budget,
    required double spent,
    required NumberFormat currencyFormatter,
  }) {
    final limit = budget.limitAmount <= 0 ? 1.0 : budget.limitAmount;
    final ratio = spent / limit;
    final clampedProgress = ratio.clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final remaining = math.max(0.0, budget.limitAmount - spent);

    // Barra verde quando confortável (< 75%), laranja quando próxima/acima do teto (>= 75%)
    final isWarning = ratio >= 0.75;
    final barColor = isWarning ? AppTheme.warningAmber : AppTheme.emeraldPrimary;
    final badgeDecoration = isWarning
        ? AppTheme.warningBadgeDecoration
        : AppTheme.emeraldBadgeDecoration;
    final badgeTextColor =
        isWarning ? AppTheme.warningDark : AppTheme.emeraldDeep;
    final statusText = ratio >= 1.0
        ? '$percent% · Teto atingido'
        : isWarning
            ? '$percent% · Próximo ao limite'
            : '$percent% · Dentro da meta';

    return Container(
      key: Key('budget_card_${budget.category}'),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isWarning
                      ? AppTheme.warningBadgeBg
                      : AppTheme.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(budget.category),
                  size: 20,
                  color: isWarning
                      ? AppTheme.warningDark
                      : AppTheme.emeraldDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Restam ${currencyFormatter.format(remaining)} neste mês',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: badgeDecoration,
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progresso (verde ou laranja)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 9,
              backgroundColor: AppTheme.subtleSurface,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 12),

          // Rodapé: Valor gasto vs. teto + Botão "Editar teto"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: currencyFormatter.format(spent),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const TextSpan(text: ' de '),
                      TextSpan(
                        text: currencyFormatter.format(budget.limitAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                key: Key('edit_budget_${budget.category}'),
                onPressed: () => _showUpsertBudgetDialog(
                  context,
                  initialCategory: budget.category,
                  initialLimit: budget.limitAmount,
                ),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Editar teto'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emeraldDeep,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: Key('delete_budget_${budget.category}'),
                tooltip: 'Apagar categoria / meta',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await ref
                      .read(appDatabaseProvider)
                      .deleteBudgetByCategory(budget.category);
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialHealthSubTab({
    required FinancialMetrics metrics,
    required UserProfile profile,
    required int displayScore,
    required String statusLabel,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card destaque Score de Saúde Financeira
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: AppTheme.heroNavyCardDecoration,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.emeraldPrimary,
                    width: 2,
                  ),
                ),
                child: Text(
                  '$displayScore',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score de Saúde Financeira · $statusLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Calculado localmente a partir da sua Taxa de Poupança (30%), Reserva de Emergência (35%) e Comprometimento de Renda (35%).',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
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

        // Cards dos 9 Indicadores Contábeis Consolidados (Motor em Dart)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Os 9 Indicadores Contábeis Consolidados (Motor Local Dart)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _HealthMetricRow(
                label: '1. Renda Mensal',
                value: currencyFormatter.format(metrics.totalIncome),
                subtitle:
                    'Renda base configurada: ${currencyFormatter.format(profile.monthlyBaseIncome)}',
                icon: Icons.arrow_upward_rounded,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '2. Despesas do Mês',
                value: currencyFormatter.format(metrics.totalExpense),
                subtitle:
                    'Burn Rate: ${currencyFormatter.format(metrics.dailyBurnRate)}/dia · Projeção: ${currencyFormatter.format(metrics.monthEndProjection)}',
                icon: Icons.arrow_downward_rounded,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '3. Saldo Atual',
                value: currencyFormatter.format(metrics.currentBalance),
                subtitle: 'Saldo líquido disponível em caixa local',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '4. Taxa de Poupança',
                value: '${metrics.savingsRate.toStringAsFixed(1)}%',
                subtitle:
                    'Meta configurada: ${profile.savingsRateTarget.toStringAsFixed(0)}% da renda',
                icon: Icons.savings_outlined,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '5. Gastos Fixos',
                value: currencyFormatter.format(metrics.fixedExpenses),
                subtitle:
                    'Moradia, educação, assinaturas e contas recorrentes',
                icon: Icons.lock_clock_outlined,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '6. Gastos Variáveis',
                value: currencyFormatter.format(metrics.variableExpenses),
                subtitle:
                    'Alimentação, transporte, lazer e consumo flexível',
                icon: Icons.tune_rounded,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '7. Comprometimento de Renda (<30%)',
                value: '${metrics.incomeCommitment.toStringAsFixed(1)}%',
                subtitle: metrics.isCommitmentWithin30Percent
                    ? 'Dentro da diretriz saudável (< 30% da renda)'
                    : 'Acima da faixa ideal de 30% — revise gastos variáveis',
                icon: Icons.pie_chart_outline_rounded,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '8. Reserva de Emergência (em meses)',
                value: '${metrics.emergencyMonths.toStringAsFixed(1)} meses',
                subtitle: 'Meta recomendada: 6 meses de custo de vida cobertos',
                icon: Icons.shield_outlined,
              ),
              const Divider(color: AppTheme.cardBorder, height: 22),
              _HealthMetricRow(
                label: '9. Patrimônio Líquido',
                value: currencyFormatter.format(metrics.netWorth),
                subtitle:
                    'Soma de Saldo Atual + reservas e investimentos acumulados',
                icon: Icons.workspace_premium_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showUpsertBudgetDialog(
    BuildContext context, {
    String? initialCategory,
    double? initialLimit,
  }) async {
    final isEditing = initialCategory != null;
    final categoryController =
        TextEditingController(text: initialCategory ?? '');
    final limitController = TextEditingController(
      text: initialLimit != null ? initialLimit.toStringAsFixed(2) : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            isEditing ? 'Editar teto mensal' : 'Nova Categoria / Meta',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('budget_dialog_category_input'),
                controller: categoryController,
                readOnly: isEditing,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  hintText: 'Ex: Saúde, Educação...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('budget_dialog_limit_input'),
                controller: limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Teto mensal (R\$)',
                  hintText: 'Ex: 800.00',
                ),
              ),
            ],
          ),
          actions: [
            if (isEditing)
              TextButton.icon(
                key: const Key('budget_dialog_delete_button'),
                onPressed: () async {
                  await ref
                      .read(appDatabaseProvider)
                      .deleteBudgetByCategory(initialCategory);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.errorColor,
                ),
                label: const Text(
                  'Apagar',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('budget_dialog_save_button'),
              onPressed: () async {
                final category = categoryController.text.trim();
                final normalizedLimit =
                    limitController.text.trim().replaceAll(',', '.');
                final parsedLimit = double.tryParse(normalizedLimit);

                if (category.isEmpty ||
                    category.toLowerCase().startsWith('renda') ||
                    parsedLimit == null ||
                    parsedLimit <= 0) {
                  return;
                }

                await ref.read(appDatabaseProvider).upsertBudget(
                      category: category,
                      limitAmount: parsedLimit,
                    );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Salvar meta'),
            ),
          ],
        );
      },
    );
  }

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('aliment')) return Icons.restaurant_rounded;
    if (lower.contains('moradia')) return Icons.home_work_outlined;
    if (lower.contains('transp')) return Icons.directions_car_outlined;
    if (lower.contains('lazer')) return Icons.movie_outlined;
    if (lower.contains('saúde') || lower.contains('saude')) {
      return Icons.favorite_border_rounded;
    }
    return Icons.category_outlined;
  }
}

class _SubTabButton extends StatelessWidget {
  const _SubTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.cardSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color:
                    isSelected ? AppTheme.emeraldDeep : AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthMetricRow extends StatelessWidget {
  const _HealthMetricRow({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.emeraldSoftBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppTheme.emeraldDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
