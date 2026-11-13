import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/domain/services/financial_health_engine.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../settings/domain/models/user_profile.dart';
import '../../../transactions/domain/models/bill.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/controllers/transactions_controller.dart';
import '../../domain/models/credit_card_model.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  int _selectedSubTab = 0; // 0 = Orçamentos & Metas, 1 = Saúde Financeira, 2 = Cartões & Limite

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(watchBudgetsProvider);
    final deletedCategoriesAsync = ref.watch(watchDeletedBudgetCategoriesProvider);
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final billsAsync = ref.watch(watchBillsProvider);
    final creditCardsAsync = ref.watch(watchCreditCardsProvider);
    final metricsAsync = ref.watch(financialMetricsStreamProvider);
    final profile = ref.watch(userProfileProvider);

    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    final transactions = transactionsAsync.value ?? const <Transaction>[];
    final bills = billsAsync.value ?? const <Bill>[];
    final creditCards = (creditCardsAsync.value ?? const <LocalCreditCard>[])
        .map(CreditCard.fromLocal)
        .toList();
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
                bills: bills,
                currencyFormatter: currencyFormatter,
                isDesktop: isDesktop,
              ),
            ] else if (_selectedSubTab == 1) ...[
              // Sub-aba "Saúde Financeira": Indicadores detalhados das 9 métricas
              _buildFinancialHealthSubTab(
                metrics: metrics,
                profile: profile,
                displayScore: displayScore,
                statusLabel: scoreStatusLabel,
                currencyFormatter: currencyFormatter,
                isDesktop: isDesktop,
              ),
            ] else ...[
              // Sub-aba "Cartões & Limite": Termômetro de uso e faixa saudável 50% a 80% (T031 / US5)
              _buildCreditCardsSubTab(
                context: context,
                creditCards: creditCards,
                transactions: transactions,
                bills: bills,
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
                    : (_selectedSubTab == 1
                        ? 'Saúde Financeira'
                        : 'Cartões & Limite'),
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
          const SizedBox(width: 4),
          Expanded(
            child: _SubTabButton(
              key: const Key('planning_tab_credit_cards'),
              label: 'Cartões & Limite',
              icon: Icons.credit_card_rounded,
              isSelected: _selectedSubTab == 2,
              onTap: () => setState(() => _selectedSubTab = 2),
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
    required List<Bill> bills,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
  }) {
    final now = DateTime.now();

    // Soma despesas do mês atual por categoria com realocação de cobranças no cartão (FR-011b / T014)
    final spentByCategory = calculateAdjustedMonthlySpendingByCategory(
      transactions: transactions,
      bills: bills,
      referenceDate: now,
    );

    // Mescla metas de LocalBudgets com categorias criadas nas Transações e Boletos que não foram excluídas
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
          userEmail: tx.userEmail ?? 'marcos.pereira@gastosync.local',
          category: rawCat,
          limitAmount: math.max(spentByCategory[key] ?? 0.0, 500.0),
          month: now.month,
          year: now.year,
        );
      }
    }

    for (final bill in bills) {
      if (bill.isDeleted) continue;
      final rawCat = bill.category.trim();
      final key = rawCat.toLowerCase();
      if (rawCat.isNotEmpty &&
          key != 'renda' &&
          !mergedByCategory.containsKey(key) &&
          !deletedCategories.contains(key)) {
        mergedByCategory[key] = LocalBudget(
          id: syntheticTxId--,
          userEmail: bill.userEmail ?? 'marcos.pereira@gastosync.local',
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

  // ---------------------------------------------------------------------------
  // SUB-ABA CARTÕES & LIMITE (T031 / US5)
  // ---------------------------------------------------------------------------

  Widget _buildCreditCardsSubTab({
    required BuildContext context,
    required List<CreditCard> creditCards,
    required List<Transaction> transactions,
    required List<Bill> bills,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
  }) {
    final summaries = CreditCardUsageSummary.calculateAll(
      cards: creditCards,
      transactions: transactions,
      bills: bills,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('planning_new_credit_card_button'),
            onPressed: () => _showUpsertCreditCardDialog(context),
            icon: const Icon(Icons.add_card_rounded, size: 20),
            label: const Text('+ Novo Cartão de Crédito'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.navyDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (summaries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.whiteCardDecoration,
            child: const Center(
              child: Text(
                'Nenhum cartão cadastrado. Adicione seu Cartão Principal acima.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else ...[
          for (var i = 0; i < summaries.length; i++) ...[
            _buildSingleCreditCardSummaryCard(
              context: context,
              summary: summaries[i],
              canDelete: summaries.length > 1 || !summaries[i].card.isPrimary,
              currencyFormatter: currencyFormatter,
            ),
            if (i < summaries.length - 1) const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget _buildSingleCreditCardSummaryCard({
    required BuildContext context,
    required CreditCardUsageSummary summary,
    required bool canDelete,
    required NumberFormat currencyFormatter,
  }) {
    final card = summary.card;
    final clampedRatio = card.limitAmount > 0
        ? (summary.totalUsedAmount / card.limitAmount).clamp(0.0, 1.0)
        : 0.0;

    final Color barColor;
    final BoxDecoration statusBadgeDeco;
    final Color statusBadgeTextColor;

    if (summary.isLimitExceeded) {
      barColor = AppTheme.errorColor;
      statusBadgeDeco = BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      );
      statusBadgeTextColor = AppTheme.errorColor;
    } else if (summary.isAboveHealthyCeiling) {
      barColor = AppTheme.warningAmber;
      statusBadgeDeco = AppTheme.warningBadgeDecoration;
      statusBadgeTextColor = AppTheme.warningDark;
    } else {
      barColor = AppTheme.emeraldPrimary;
      statusBadgeDeco = AppTheme.emeraldBadgeDecoration;
      statusBadgeTextColor = AppTheme.emeraldDeep;
    }

    return Container(
      key: Key('planning_credit_card_${card.id ?? card.name}'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: card.isPrimary
                      ? AppTheme.navyDark
                      : AppTheme.subtleSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  size: 20,
                  color:
                      card.isPrimary ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (card.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: AppTheme.emeraldBadgeDecoration,
                            child: const Text(
                              'Principal',
                              style: TextStyle(
                                color: AppTheme.emeraldDeep,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Limite Total: ${currencyFormatter.format(card.limitAmount)} · Vencimento dia ${card.dueDay}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('edit_credit_card_${card.id ?? card.name}'),
                tooltip: 'Editar cartão e faixa saudável',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    _showUpsertCreditCardDialog(context, existing: card),
              ),
              if (canDelete && card.id != null && card.id! > 0)
                IconButton(
                  key: Key('delete_credit_card_${card.id}'),
                  tooltip: 'Remover cartão',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () {
                    ref.read(appDatabaseProvider).deleteCreditCard(card.id!);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Uso Total vs Limite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL UTILIZADO NO MÊS (FIXAS + COMPRAS)',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${currencyFormatter.format(summary.totalUsedAmount)} (${summary.utilizationPercent.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: statusBadgeDeco,
                  child: Text(
                    summary.relationshipStatusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusBadgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clampedRatio,
              minHeight: 10,
              backgroundColor: AppTheme.subtleSurface,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 14),

          // Divisão: Assinaturas Fixas vs Compras Variáveis no Cartão
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fixas / Assinaturas',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(
                          summary.fixedSubscriptionsAmount,
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${summary.fixedSubscriptionsCount} conta(s) na fatura',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compras no Crédito',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(
                          summary.variablePurchasesAmount,
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${summary.variablePurchasesCount} lançamento(s)',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Faixa Saudável de Relacionamento Bancário (50% a 80%)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: summary.isAboveHealthyCeiling
                  ? AppTheme.warningBadgeBg.withValues(alpha: 0.55)
                  : AppTheme.emeraldSoftBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: summary.isAboveHealthyCeiling
                    ? AppTheme.warningBorder
                    : AppTheme.emeraldBadgeBg,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  summary.isAboveHealthyCeiling
                      ? Icons.warning_amber_rounded
                      : Icons.trending_up_rounded,
                  size: 18,
                  color: summary.isAboveHealthyCeiling
                      ? AppTheme.warningDark
                      : AppTheme.emeraldDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.isAboveHealthyCeiling
                        ? 'Atenção: você ultrapassou o teto saudável de ${card.targetMaxPercent.toStringAsFixed(0)}% (${currencyFormatter.format(summary.healthyMaxAmount)}) em ${currencyFormatter.format(summary.amountAboveHealthyCeiling)}. Limite total restante: ${currencyFormatter.format(summary.remainingTotalLimit)}.'
                        : 'Faixa saudável para relacionamento bancário (${card.targetMinPercent.toStringAsFixed(0)}%–${card.targetMaxPercent.toStringAsFixed(0)}%): ${currencyFormatter.format(summary.healthyMinAmount)} a ${currencyFormatter.format(summary.healthyMaxAmount)} · Margem saudável restante: ${currencyFormatter.format(summary.remainingHealthyMargin)}.',
                    style: TextStyle(
                      color: summary.isAboveHealthyCeiling
                          ? AppTheme.warningDark
                          : AppTheme.emeraldDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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

  Future<void> _showUpsertCreditCardDialog(
    BuildContext context, {
    CreditCard? existing,
  }) async {
    final nameCtrl = TextEditingController(
      text: existing?.name ?? 'Cartão Secundário',
    );
    final limitCtrl = TextEditingController(
      text: (existing?.limitAmount ?? 1500.0).toStringAsFixed(2),
    );
    final minPctCtrl = TextEditingController(
      text: (existing?.targetMinPercent ?? 50.0).toStringAsFixed(0),
    );
    final maxPctCtrl = TextEditingController(
      text: (existing?.targetMaxPercent ?? 80.0).toStringAsFixed(0),
    );
    final dueDayCtrl = TextEditingController(
      text: (existing?.dueDay ?? 10).toString(),
    );
    var isPrimary = existing?.isPrimary ?? false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardSurface,
              title: Text(
                existing != null
                    ? 'Editar ${existing.name}'
                    : 'Novo Cartão de Crédito',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Cartão',
                        hintText: 'Ex: Cartão Principal, Cartão Secundário',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Limite Total (R\$)',
                        hintText: 'Ex: 1500.00',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPctCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Piso Ideal (%)',
                              hintText: '50',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxPctCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Teto Saudável (%)',
                              hintText: '80',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dueDayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia de Vencimento da Fatura (1 a 31)',
                        hintText: '10',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Definir como Cartão Principal',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: isPrimary,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppTheme.emeraldPrimary,
                      onChanged: (val) =>
                          setDialogState(() => isPrimary = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final limit = double.tryParse(
                      limitCtrl.text.trim().replaceAll(',', '.'),
                    );
                    final minPct = double.tryParse(
                          minPctCtrl.text.trim().replaceAll(',', '.'),
                        ) ??
                        50.0;
                    final maxPct = double.tryParse(
                          maxPctCtrl.text.trim().replaceAll(',', '.'),
                        ) ??
                        80.0;
                    final dueDay =
                        int.tryParse(dueDayCtrl.text.trim()) ?? 10;

                    if (name.isEmpty || limit == null || limit <= 0) return;

                    await ref.read(appDatabaseProvider).upsertCreditCard(
                          id: existing?.id,
                          clientUuid: existing?.clientUuid,
                          name: name,
                          limitAmount: limit,
                          targetMinPercent: minPct,
                          targetMaxPercent: maxPct,
                          dueDay: dueDay,
                          isPrimary: isPrimary,
                        );

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Salvar Cartão'),
                ),
              ],
            );
          },
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
