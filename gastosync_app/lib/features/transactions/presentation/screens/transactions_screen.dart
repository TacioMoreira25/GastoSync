import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/csv_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/brl_currency_formatter.dart';
import '../../../planning/domain/models/credit_card_model.dart';
import '../../../settings/domain/models/user_profile.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/transaction.dart';
import '../controllers/transactions_controller.dart';
import '../widgets/manual_transaction_form_modal.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedYearMonthKey =
      DateTime.now().year * 100 + DateTime.now().month;
  int? _selectedDay;
  String _txTypeFilter = 'all'; // 'all', 'expense', 'income'
  String _billStatusFilter = 'all'; // 'all', 'pending', 'overdue', 'paid'

  static const List<String> _monthNamesFull = <String>[
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

  String _formatYearMonthLabel(int ym) {
    final year = ym ~/ 100;
    final month = (ym % 100).clamp(1, 12);
    return '${_monthNamesFull[month - 1]} $year';
  }

  static const List<String> _defaultCategories = <String>[
    'Alimentação',
    'Moradia',
    'Transporte',
    'Lazer',
    'Saúde',
    'Renda',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCopyBarcode(BuildContext context, Bill bill) async {
    final code = bill.barcode.trim();
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Código de "${bill.description}" copiado para a área de transferência!',
        ),
      ),
    );
  }

  Future<void> _handlePayBill(BuildContext context, Bill bill) async {
    if (bill.id == null) return;
    try {
      final result =
          await ref.read(transactionsControllerProvider).payBill(bill.id!);
      if (!context.mounted) return;

      final recurrenceSuffix = result.nextRecurringBillId != null
          ? ' Próximo mês agendado automaticamente.'
          : '';
      final message = result.isCreditCardCharge
          ? 'Cobrança "${bill.description}" confirmada no cartão (sem descontar 2x do saldo).$recurrenceSuffix'
          : 'Baixa realizada em "${bill.description}"! Despesa lançada no extrato.$recurrenceSuffix';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Erro ao dar baixa no boleto: $e'),
        ),
      );
    }
  }

  Future<void> _handleUnpayBill(BuildContext context, Bill bill) async {
    if (bill.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar pagamento?'),
        content: Text(
          bill.isCreditCardCharge
              ? 'O lançamento "${bill.description}" voltará para pendente.'
              : 'O boleto "${bill.description}" voltará para pendente e a despesa vinculada será removida do extrato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final reverted =
          await ref.read(transactionsControllerProvider).unpayBill(bill.id!);
      if (!context.mounted) return;
      if (reverted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              bill.isCreditCardCharge
                  ? 'Confirmação de "${bill.description}" desfeita.'
                  : 'Pagamento de "${bill.description}" estornado e despesa removida do extrato.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Erro ao estornar boleto: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final billsAsync = ref.watch(watchBillsProvider);
    final creditCardsAsync = ref.watch(watchCreditCardsProvider);
    final profile = ref.watch(userProfileProvider);
    final pendingBillsCount = ref.watch(pendingBillsCountProvider);
    final selectedSubTab = ref.watch(selectedTransactionsSubTabProvider);
    final budgets = ref.watch(watchBudgetsProvider).value ?? const <LocalBudget>[];
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;

    final bills =
        (billsAsync.value ?? const <Bill>[]).where((b) => !b.isDeleted).toList();
    final creditCards = (creditCardsAsync.value ?? const <LocalCreditCard>[])
        .map(CreditCard.fromLocal)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Erro ao carregar transações locais: $err'),
        ),
        data: (transactions) {
          final syncedCount = transactions.where((t) => t.isSynced).length;
          final pendingCount = transactions.length - syncedCount;

          // Combina categorias padrão + metas criadas no Planejamento + categorias das transações e boletos
          final categoryMap = <String, String>{};
          for (final c in _defaultCategories) {
            categoryMap[c.trim().toLowerCase()] = c.trim();
          }
          for (final b in budgets) {
            final trimmed = b.category.trim();
            if (trimmed.isNotEmpty) {
              categoryMap.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
            }
          }
          for (final t in transactions) {
            final trimmed = t.category.trim();
            if (trimmed.isNotEmpty) {
              categoryMap.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
            }
          }
          for (final bill in bills) {
            final trimmed = bill.category.trim();
            if (trimmed.isNotEmpty) {
              categoryMap.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
            }
          }
          final categories = categoryMap.values.toList();

          final now = DateTime.now();
          final yearMonthSet = <int>{now.year * 100 + now.month};
          for (final t in transactions) {
            yearMonthSet.add(t.date.year * 100 + t.date.month);
          }
          for (final bill in bills) {
            yearMonthSet.add(bill.dueDate.year * 100 + bill.dueDate.month);
          }
          if (_selectedYearMonthKey != null) {
            yearMonthSet.add(_selectedYearMonthKey!);
          }
          final availableYearMonths = yearMonthSet.toList()
            ..sort((a, b) => b.compareTo(a));

          // Filtra transações por categoria, tipo, mês/dia e termo de pesquisa
          final query = _searchQuery.trim().toLowerCase();
          final filteredTransactions = transactions.where((tx) {
            final matchesMonth = _selectedYearMonthKey == null ||
                (tx.date.year * 100 + tx.date.month) == _selectedYearMonthKey;
            if (!matchesMonth) return false;

            final matchesDay =
                _selectedDay == null || tx.date.day <= _selectedDay!;
            if (!matchesDay) return false;

            if (_txTypeFilter == 'expense' && !tx.isExpense) return false;
            if (_txTypeFilter == 'income' && !tx.isIncome) return false;

            final matchesCategory = selectedCategory == null ||
                tx.category.toLowerCase() == selectedCategory.toLowerCase() ||
                (selectedCategory == 'Renda' && tx.isIncome);

            if (!matchesCategory) return false;
            if (query.isEmpty) return true;

            return tx.description.toLowerCase().contains(query) ||
                tx.category.toLowerCase().contains(query);
          }).toList();

          // Filtra boletos por categoria, status, mês/dia e termo de pesquisa
          final filteredBills = bills.where((bill) {
            final matchesMonth = _selectedYearMonthKey == null ||
                (bill.dueDate.year * 100 + bill.dueDate.month) ==
                    _selectedYearMonthKey;
            if (!matchesMonth) return false;

            final matchesDay =
                _selectedDay == null || bill.dueDate.day <= _selectedDay!;
            if (!matchesDay) return false;

            if (_billStatusFilter == 'pending' &&
                (bill.isPaid || bill.isOverdue())) {
              return false;
            }
            if (_billStatusFilter == 'overdue' && !bill.isOverdue()) {
              return false;
            }
            if (_billStatusFilter == 'paid' && !bill.isPaid) {
              return false;
            }

            final matchesCategory = selectedCategory == null ||
                bill.category.toLowerCase() == selectedCategory.toLowerCase();
            if (!matchesCategory) return false;
            if (query.isEmpty) return true;

            return bill.description.toLowerCase().contains(query) ||
                bill.category.toLowerCase().contains(query) ||
                bill.barcode.toLowerCase().contains(query);
          }).toList();

          final periodLabel = _selectedYearMonthKey != null
              ? _formatYearMonthLabel(_selectedYearMonthKey!)
              : 'Todos os meses';
          final selectedMonthDate = _selectedYearMonthKey != null
              ? DateTime(
                  _selectedYearMonthKey! ~/ 100,
                  (_selectedYearMonthKey! % 100).clamp(1, 12),
                  15,
                )
              : DateTime.now();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28.0 : (screenWidth < 360 ? 12.0 : 16.0),
              isDesktop ? 24.0 : 16.0,
              isDesktop ? 28.0 : (screenWidth < 360 ? 12.0 : 16.0),
              isDesktop ? 48.0 : 124.0 + bottomSafeInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cabeçalho MOVIMENTAÇÕES + Badge verde "X sincronizadas" + Exportar CSV (T033)
                _buildHeaderSection(
                  context: context,
                  syncedCount: syncedCount,
                  pendingCount: pendingCount,
                  totalCount: transactions.length,
                  selectedSubTab: selectedSubTab,
                  isDesktop: isDesktop,
                  onExportCsv: () => CsvExportService.showExportModal(
                    context,
                    transactions: transactions,
                    bills: bills,
                    creditCards: creditCards,
                    userEmail: profile.email,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Seletor segmentado ("Lançamentos" | "Boletos" | "Cartões")
                _buildSubTabSelector(
                  selectedSubTab: selectedSubTab,
                  transactionsCount: filteredTransactions.length,
                  pendingBillsCount: pendingBillsCount,
                  creditCardsCount: creditCards.length,
                ),
                const SizedBox(height: 16),

                if (selectedSubTab == 0) ...[
                  _buildTransactionsSummaryStrip(
                    filtered: filteredTransactions,
                    periodLabel: periodLabel,
                    currencyFormatter: currencyFormatter,
                  ),
                  const SizedBox(height: 14),
                ],

                if (selectedSubTab == 1) ...[
                  // Resumo de Boletos FIEL AO PERÍODO FILTRADO (Novembro, Dezembro, etc.)
                  _buildBillsSummarySection(
                    context: context,
                    bills: filteredBills,
                    periodLabel: periodLabel,
                    currencyFormatter: currencyFormatter,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 16),
                ],

                // 3b. Filtro por Mês e Dia (em Cartões, navega apenas por Mês)
                _buildDateFilterBar(
                  context: context,
                  availableYearMonths: availableYearMonths,
                  isCardsTab: selectedSubTab == 2,
                ),
                const SizedBox(height: 12),

                if (selectedSubTab != 2) ...[
                  // 3. Barra de pesquisa
                  _buildSearchBar(selectedSubTab: selectedSubTab),
                  const SizedBox(height: 10),

                  // 3c. Filtros rápidos de Tipo (Lançamentos) ou Status (Boletos)
                  _buildQuickTypeOrStatusFilters(
                    selectedSubTab: selectedSubTab,
                  ),
                  const SizedBox(height: 10),

                  // 4. Chips horizontais de categoria sem scrollbar visível
                  _buildCategoryFilterChips(
                    context: context,
                    categories: categories,
                    selectedCategory: selectedCategory,
                  ),
                  const SizedBox(height: 18),
                ] else
                  const SizedBox(height: 6),

                // 5. Conteúdo da sub-aba ativa
                if (selectedSubTab == 0)
                  _buildUnifiedTransactionsCard(
                    context: context,
                    filtered: filteredTransactions,
                    currencyFormatter: currencyFormatter,
                    dateFormatter: dateFormatter,
                  )
                else if (selectedSubTab == 1)
                  _buildUnifiedBillsCard(
                    context: context,
                    filteredBills: filteredBills,
                    currencyFormatter: currencyFormatter,
                    dateFormatter: dateFormatter,
                  )
                else
                  _buildCreditCardsInvoiceTab(
                    context: context,
                    cards: creditCards,
                    transactions: transactions,
                    bills: bills,
                    referenceDate: selectedMonthDate,
                    periodLabel: _formatYearMonthLabel(
                      selectedMonthDate.year * 100 + selectedMonthDate.month,
                    ),
                    currencyFormatter: currencyFormatter,
                    dateFormatter: dateFormatter,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection({
    required BuildContext context,
    required int syncedCount,
    required int pendingCount,
    required int totalCount,
    required int selectedSubTab,
    required bool isDesktop,
    required VoidCallback onExportCsv,
  }) {
    final badgeLabel = '$syncedCount sincronizada${syncedCount == 1 ? '' : 's'}';

    final syncedBadge = Container(
      key: const Key('transactions_synced_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AppTheme.emeraldBadgeDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppTheme.emeraldDeep,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            badgeLabel,
            style: const TextStyle(
              color: AppTheme.emeraldDeep,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final pendingBadge = pendingCount > 0
        ? Container(
            key: const Key('transactions_pending_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: AppTheme.warningBadgeDecoration,
            child: Text(
              '$pendingCount pendente${pendingCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppTheme.warningDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MOVIMENTAÇÕES',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selectedSubTab == 0 ? 'Transações' : 'Boletos e Contas a Pagar',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isDesktop ? 22 : 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleBlock),
              IconButton(
                key: const Key('transactions_export_csv_button'),
                tooltip: 'Exportar CSV',
                onPressed: onExportCsv,
                icon: const Icon(
                  Icons.download_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [syncedBadge, ?pendingBadge],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleBlock),
        syncedBadge,
        if (pendingBadge != null) ...[
          const SizedBox(width: 8),
          pendingBadge,
        ],
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const Key('transactions_export_csv_button'),
          onPressed: onExportCsv,
          icon: const Icon(Icons.download_rounded, size: 17),
          label: const Text('Exportar CSV'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.cardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          key: const Key('add_transaction_fab'),
          onPressed: () => ManualTransactionFormModal.show(
            context,
            startInBillMode: selectedSubTab == 1,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            selectedSubTab == 1 ? 'Novo Boleto' : 'Nova Transação',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.emeraldPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabSelector({
    required int selectedSubTab,
    required int transactionsCount,
    required int pendingBillsCount,
    required int creditCardsCount,
  }) {
    return Container(
      key: const Key('transactions_subtab_selector'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('subtab_lancamentos_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => ref
                  .read(selectedTransactionsSubTabProvider.notifier)
                  .selectSubTab(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedSubTab == 0
                      ? AppTheme.navyDark
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lançamentos ($transactionsCount)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedSubTab == 0
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        selectedSubTab == 0 ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: const Key('subtab_boletos_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => ref
                  .read(selectedTransactionsSubTabProvider.notifier)
                  .selectSubTab(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedSubTab == 1
                      ? AppTheme.navyDark
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Boletos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedSubTab == 1
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: selectedSubTab == 1
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (pendingBillsCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selectedSubTab == 1
                              ? AppTheme.warningAmber
                              : AppTheme.warningBadgeBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$pendingBillsCount',
                          style: TextStyle(
                            color: selectedSubTab == 1
                                ? Colors.white
                                : AppTheme.warningDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: const Key('subtab_cartoes_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => ref
                  .read(selectedTransactionsSubTabProvider.notifier)
                  .selectSubTab(2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedSubTab == 2
                      ? AppTheme.navyDark
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  creditCardsCount > 0
                      ? 'Cartões ($creditCardsCount)'
                      : 'Cartões',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedSubTab == 2
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        selectedSubTab == 2 ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSummaryStrip({
    required List<Transaction> filtered,
    required String periodLabel,
    required NumberFormat currencyFormatter,
  }) {
    final totalIncome = TransactionCalculations.calculateTotalIncome(filtered);
    final totalExpense =
        TransactionCalculations.calculateTotalExpense(filtered);
    final balance = totalIncome - totalExpense;

    return Container(
      key: const Key('transactions_filtered_summary_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMO FILTRADO • ${periodLabel.toUpperCase()}',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entradas',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyFormatter.format(totalIncome),
                        style: const TextStyle(
                          color: AppTheme.emeraldPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saídas',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyFormatter.format(totalExpense),
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyFormatter.format(balance),
                        style: TextStyle(
                          color: balance >= 0
                              ? AppTheme.textPrimary
                              : AppTheme.errorColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTypeOrStatusFilters({required int selectedSubTab}) {
    if (selectedSubTab == 0) {
      final options = <MapEntry<String, String>>[
        const MapEntry('all', 'Todos'),
        const MapEntry('expense', 'Despesas'),
        const MapEntry('income', 'Receitas'),
      ];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((entry) {
            final selected = _txTypeFilter == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('tx_type_filter_${entry.key}'),
                label: Text(entry.value),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppTheme.navyDark,
                backgroundColor: AppTheme.cardSurface,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _txTypeFilter = entry.key),
              ),
            );
          }).toList(),
        ),
      );
    }

    final statusOptions = <MapEntry<String, String>>[
      const MapEntry('all', 'Todos'),
      const MapEntry('pending', 'Pendentes'),
      const MapEntry('overdue', 'Vencidos'),
      const MapEntry('paid', 'Pagos'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusOptions.map((entry) {
          final selected = _billStatusFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: Key('bill_status_filter_${entry.key}'),
              label: Text(entry.value),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppTheme.navyDark,
              backgroundColor: AppTheme.cardSurface,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _billStatusFilter = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCreditCardsInvoiceTab({
    required BuildContext context,
    required List<CreditCard> cards,
    required List<Transaction> transactions,
    required List<Bill> bills,
    required DateTime referenceDate,
    required String periodLabel,
    required NumberFormat currencyFormatter,
    required DateFormat dateFormatter,
  }) {
    final summaries = CreditCardUsageSummary.calculateAll(
      cards: cards,
      transactions: transactions,
      bills: bills,
      referenceDate: referenceDate,
    );

    if (summaries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.whiteCardDecoration,
        child: Column(
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 40,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 10),
            const Text(
              'Nenhum cartão cadastrado ainda',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cadastre um cartão ao lançar uma compra no crédito ou em Planejamento para acompanhar suas faturas aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    final refMonthKey = CreditCard.formatYearMonth(referenceDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('transactions_new_credit_card_button'),
              onPressed: () => _showCreditCardDialogFromTransactions(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.navyDark,
                backgroundColor: AppTheme.cardSurface,
                side: const BorderSide(color: AppTheme.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text(
                'Novo Cartão de Crédito',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        ...summaries.map((summary) {
        final card = summary.card;
        final cardUuid = card.clientUuid.trim();
        final acceptUnassigned =
            card.isPrimary || (!cards.any((c) => c.isPrimary) && cards.first.id == card.id);

        bool matchesCard(String? itemCardUuid) {
          final norm = itemCardUuid?.trim() ?? '';
          if (norm.isEmpty) return acceptUnassigned;
          return cardUuid.isNotEmpty && norm == cardUuid;
        }

        final cycle = card.invoiceCycleForMonth(referenceDate);
        final cardTransactions = transactions.where((tx) {
          if (tx.isDeleted || !tx.isExpense) return false;
          if (tx.date.isBefore(cycle.start) || tx.date.isAfter(cycle.end)) {
            return false;
          }
          final lower = tx.paymentMethod.trim().toLowerCase();
          final isCredit = lower == 'crédito' ||
              lower == 'credito' ||
              lower == 'cartão de crédito' ||
              lower == 'cartao de credito';
          return isCredit && matchesCard(tx.creditCardUuid);
        }).toList();

        final cardBills = bills.where((b) {
          if (b.isDeleted || !b.isCreditCardCharge) return false;
          if (b.dueDate.isBefore(cycle.start) ||
              b.dueDate.isAfter(cycle.end)) {
            return false;
          }
          return matchesCard(b.creditCardUuid);
        }).toList();

        final launchedAmount =
            cardTransactions.fold<double>(0.0, (s, tx) => s + tx.amount) +
                cardBills
                    .where((b) => b.isPaid)
                    .fold<double>(0.0, (s, b) => s + b.amount);
        final plannedAmount = cardBills
            .where((b) => !b.isPaid)
            .fold<double>(0.0, (s, b) => s + b.amount);
        final allCardBillsForMonth = cardBills;
        final closingDay = card.closingDay;

        final progress = card.limitAmount > 0
            ? (summary.totalUsedAmount / card.limitAmount).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          key: Key('transactions_card_invoice_${card.id ?? card.name}'),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.navyDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      size: 18,
                      color: AppTheme.navyDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                card.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
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
                        Text(
                          'Fatura de $periodLabel • Fecha dia $closingDay • Vence dia ${card.dueDay}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormatter.format(summary.totalUsedAmount),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'de ${currencyFormatter.format(card.limitAmount)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (card.id != null && card.id! > 0) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: Key('transactions_edit_card_${card.id}'),
                      tooltip: 'Editar cartão',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => _showCreditCardDialogFromTransactions(
                        context,
                        existing: card,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: AppTheme.subtleSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    summary.isLimitExceeded
                        ? AppTheme.errorColor
                        : (summary.isAboveHealthyCeiling
                            ? AppTheme.warningAmber
                            : AppTheme.emeraldPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Limite disponível: ${currencyFormatter.format(summary.remainingTotalLimit)}',
                    style: const TextStyle(
                      color: AppTheme.emeraldDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${summary.utilizationPercent.toStringAsFixed(0)}% usado',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (launchedAmount > 0 || plannedAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Já lançado: ${currencyFormatter.format(launchedAmount)}  •  Previsto no ciclo: ${currencyFormatter.format(plannedAmount)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (summary.hasManualInvoice) ...[
                const SizedBox(height: 8),
                Text(
                  summary.untrackedInvoiceDifference > 0.01
                      ? 'Fatura informada • Detalhado no app: ${currencyFormatter.format(summary.trackedUsedAmount)} (+ ${currencyFormatter.format(summary.untrackedInvoiceDifference)} outros)'
                      : 'Fatura informada manualmente (${currencyFormatter.format(summary.totalUsedAmount)}) • Detalhado no app: ${currencyFormatter.format(summary.trackedUsedAmount)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (card.id != null && card.id! > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showManualInvoiceDialogFromTransactions(
                        context: context,
                        summary: summary,
                        yearMonth: refMonthKey,
                        periodLabel: periodLabel,
                        currencyFormatter: currencyFormatter,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.navyDark,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: Text(
                        summary.hasManualInvoice
                            ? 'Ajustar fatura'
                            : 'Informar valor da fatura',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (summary.hasManualInvoice)
                      TextButton.icon(
                        onPressed: () async {
                          await ref
                              .read(transactionsControllerProvider)
                              .updateCreditCardManualInvoice(
                                card.id!,
                                amount: null,
                                yearMonth: null,
                              );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.autorenew_rounded, size: 15),
                        label: const Text(
                          'Voltar ao automático',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4),
                title: Text(
                  'Itens inclusos nesta fatura (${cardTransactions.length + allCardBillsForMonth.length})',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  if (cardTransactions.isEmpty && allCardBillsForMonth.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhuma compra ou assinatura detalhada neste cartão neste mês.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (cardTransactions.isNotEmpty ||
                      allCardBillsForMonth.any((b) => b.isPaid)) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'JÁ LANÇADOS NA FATURA',
                          style: TextStyle(
                            color: AppTheme.emeraldDeep,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    ...cardTransactions.map(
                      (tx) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                          color: AppTheme.emeraldPrimary,
                        ),
                        title: Text(
                          tx.description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${tx.category} • ${dateFormatter.format(tx.date)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          currencyFormatter.format(tx.amount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => ManualTransactionFormModal.show(
                          context,
                          initialTransaction: tx,
                        ),
                      ),
                    ),
                    ...allCardBillsForMonth.where((b) => b.isPaid).map(
                          (b) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: AppTheme.emeraldPrimary,
                            ),
                            title: Text(
                              b.description,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Confirmada na fatura • ${dateFormatter.format(b.dueDate)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              currencyFormatter.format(b.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => ManualTransactionFormModal.show(
                              context,
                              initialBill: b,
                            ),
                          ),
                        ),
                  ],
                  if (allCardBillsForMonth.any((b) => !b.isPaid)) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PREVISTO (AINDA VAI ENTRAR / VENCER)',
                          style: TextStyle(
                            color: AppTheme.warningDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    ...allCardBillsForMonth.where((b) => !b.isPaid).map(
                          (b) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: AppTheme.warningAmber,
                            ),
                            title: Text(
                              b.description,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Previsto • Vence ${dateFormatter.format(b.dueDate)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              currencyFormatter.format(b.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            onTap: () => ManualTransactionFormModal.show(
                              context,
                              initialBill: b,
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ],
          ),
        );
      }),
      ],
    );
  }

  Future<void> _showCreditCardDialogFromTransactions(
    BuildContext context, {
    CreditCard? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final limitController = TextEditingController(
      text: existing != null
          ? BrlCurrencyInputFormatter.formatValue(existing.limitAmount)
          : '',
    );
    final dueDayController = TextEditingController(
      text: (existing?.dueDay ?? 10).toString(),
    );
    final closingDayController = TextEditingController(
      text: (existing?.closingDay ?? 3).toString(),
    );
    var isPrimary = existing?.isPrimary ?? false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Editar Cartão' : 'Novo Cartão'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do cartão (ex: Nubank)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe o nome do cartão.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [BrlCurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Limite total (R\$)',
                      prefixText: 'R\$ ',
                    ),
                    validator: (v) =>
                        BrlCurrencyInputFormatter.parseValue(v ?? '') <= 0
                            ? 'Informe um limite maior que zero.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: closingDayController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Dia fechamento (1–31)',
                          ),
                          validator: (v) {
                            final day = int.tryParse((v ?? '').trim());
                            if (day == null || day < 1 || day > 31) {
                              return 'Inválido (1–31).';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: dueDayController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Dia vencimento (1–31)',
                          ),
                          validator: (v) {
                            final day = int.tryParse((v ?? '').trim());
                            if (day == null || day < 1 || day > 31) {
                              return 'Inválido (1–31).';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Cartão Principal',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    value: isPrimary,
                    onChanged: (v) => setDialogState(() => isPrimary = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null && existing.id != null && existing.id! > 0)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: dialogContext,
                    builder: (confirmCtx) => AlertDialog(
                      title: const Text('Apagar cartão?'),
                      content: Text(
                        'Tem certeza que deseja apagar o cartão "${existing.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(confirmCtx).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(confirmCtx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                          ),
                          child: const Text('Apagar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !dialogContext.mounted) return;
                  final allBills =
                      ref.read(watchBillsProvider).value ?? const <Bill>[];
                  final affectedBillsCount = allBills
                      .where(
                        (b) =>
                            !b.isDeleted &&
                            b.creditCardUuid != null &&
                            b.creditCardUuid!.trim() ==
                                existing.clientUuid.trim(),
                      )
                      .length;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(dialogContext).pop();
                  await ref
                      .read(transactionsControllerProvider)
                      .deleteCreditCard(existing.id!);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        affectedBillsCount > 0
                            ? 'Cartão "${existing.name}" apagado. $affectedBillsCount conta(s) ficaram sem cartão — edite-as em Boletos para escolher outro cartão.'
                            : 'Cartão "${existing.name}" apagado.',
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Apagar'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emeraldPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final limit =
                    BrlCurrencyInputFormatter.parseValue(limitController.text);
                final dueDay = int.parse(dueDayController.text.trim());
                final closingDay = int.parse(closingDayController.text.trim());
                Navigator.of(dialogContext).pop();
                await ref.read(transactionsControllerProvider).upsertCreditCard(
                      id: existing?.id,
                      clientUuid: existing?.clientUuid,
                      name: nameController.text.trim(),
                      limitAmount: limit,
                      targetMinPercent: existing?.targetMinPercent ?? 50.0,
                      targetMaxPercent: existing?.targetMaxPercent ?? 80.0,
                      dueDay: dueDay,
                      closingDay: closingDay,
                      isPrimary: isPrimary,
                    );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      nameController.dispose();
      limitController.dispose();
      dueDayController.dispose();
      closingDayController.dispose();
    });
  }

  Future<void> _showManualInvoiceDialogFromTransactions({
    required BuildContext context,
    required CreditCardUsageSummary summary,
    required String yearMonth,
    required String periodLabel,
    required NumberFormat currencyFormatter,
  }) async {
    final card = summary.card;
    if (card.id == null) return;
    final initialValue = summary.hasManualInvoice
        ? summary.manualInvoiceAmount!
        : summary.trackedUsedAmount;
    final amountController = TextEditingController(
      text: initialValue > 0
          ? BrlCurrencyInputFormatter.formatValue(initialValue)
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Fatura de $periodLabel • ${card.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lançado no app neste mês: ${currencyFormatter.format(summary.trackedUsedAmount)}.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [BrlCurrencyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Valor da fatura (R\$)',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final parsed = BrlCurrencyInputFormatter.parseValue(
                amountController.text,
              );
              Navigator.of(dialogContext).pop();
              await ref
                  .read(transactionsControllerProvider)
                  .updateCreditCardManualInvoice(
                    card.id!,
                    amount: parsed,
                    yearMonth: yearMonth,
                  );
            },
            child: const Text('Salvar fatura'),
          ),
        ],
      ),
    );
    amountController.dispose();
  }

  Widget _buildBillsSummarySection({
    required BuildContext context,
    required List<Bill> bills,
    required String periodLabel,
    required NumberFormat currencyFormatter,
    required bool isDesktop,
  }) {
    final totalRealToPay =
        BillCalculations.calculateTotalPendingCashOutflow(bills);
    final totalCreditCardReminders =
        BillCalculations.calculateTotalCreditCardCharges(bills);

    final unpaidCashBills =
        bills.where((b) => !b.isPaid && !b.isCreditCardCharge).toList();
    final overdueCount = unpaidCashBills.where((b) => b.isOverdue()).length;
    final dueTodayCount = unpaidCashBills.where((b) => b.isDueToday()).length;
    final cardReminderCount =
        bills.where((b) => b.isCreditCardCharge && !b.isPaid).length;

    final realToPayCard = Container(
      key: const Key('bills_total_real_to_pay_card'),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningBadgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppTheme.warningDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A PAGAR • ${periodLabel.toUpperCase()}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('add_new_bill_button'),
                onPressed: () => ManualTransactionFormModal.show(
                  context,
                  startInBillMode: true,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.emeraldDeep,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                label: const Text(
                  'Novo Boleto',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currencyFormatter.format(totalRealToPay),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${unpaidCashBills.length} boleto${unpaidCashBills.length == 1 ? "" : "s"} pendente${unpaidCashBills.length == 1 ? "" : "s"}'
            '${overdueCount > 0 ? " · $overdueCount vencido${overdueCount == 1 ? "" : "s"}" : ""}'
            '${dueTodayCount > 0 ? " · $dueTodayCount vence${dueTodayCount == 1 ? "" : "m"} hoje" : ""}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final creditCardChargesCard = Container(
      key: const Key('bills_credit_card_charges_card'),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  size: 18,
                  color: AppTheme.emeraldDeep,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'LEMBRETES NO CARTÃO (INCLUSOS NA FATURA)',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currencyFormatter.format(totalCreditCardReminders),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$cardReminderCount cobrança${cardReminderCount == 1 ? "" : "s"} pendente${cardReminderCount == 1 ? "" : "s"} no cartão · Não soma duplicado no total a pagar',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: realToPayCard),
          const SizedBox(width: 16),
          Expanded(child: creditCardChargesCard),
        ],
      );
    }

    return Column(
      children: [
        realToPayCard,
        const SizedBox(height: 12),
        creditCardChargesCard,
      ],
    );
  }

  Widget _buildSearchBar({required int selectedSubTab}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
      ),
      child: TextField(
        key: const Key('transactions_search_input'),
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: selectedSubTab == 0
              ? 'Pesquisar transações, categorias...'
              : 'Pesquisar boletos, linha digitável, categorias...',
          hintStyle: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textMuted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  tooltip: 'Limpar pesquisa',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterBar({
    required BuildContext context,
    required List<int> availableYearMonths,
    bool isCardsTab = false,
  }) {
    final now = DateTime.now();
    final hasMonth = _selectedYearMonthKey != null;
    final hasDay = _selectedDay != null;
    final monthLabel = hasMonth
        ? _formatYearMonthLabel(_selectedYearMonthKey!)
        : 'Mês: Todos';

    Future<void> pickDateFromCalendar() async {
      final initialDate = _selectedYearMonthKey != null
          ? DateTime(
              _selectedYearMonthKey! ~/ 100,
              (_selectedYearMonthKey! % 100).clamp(1, 12),
              (_selectedDay ?? 1).clamp(1, 28),
            )
          : now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedYearMonthKey = picked.year * 100 + picked.month;
          _selectedDay = picked.day;
        });
      }
    }

    void shiftMonth(int delta) {
      final base = _selectedYearMonthKey != null
          ? DateTime(
              _selectedYearMonthKey! ~/ 100,
              (_selectedYearMonthKey! % 100).clamp(1, 12),
              1,
            )
          : DateTime(now.year, now.month, 1);
      final target = DateTime(base.year, base.month + delta, 1);
      setState(() {
        _selectedYearMonthKey = target.year * 100 + target.month;
        _selectedDay = null;
      });
    }

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          key: const Key('transactions_prev_month_button'),
          tooltip: 'Mês anterior',
          visualDensity: VisualDensity.compact,
          onPressed: () => shiftMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
        ),
        InkWell(
          key: const Key('transactions_month_filter_button'),
          borderRadius: BorderRadius.circular(999),
          onTap: isCardsTab ? null : pickDateFromCalendar,
          child: _DateFilterChipLabel(
            icon: Icons.calendar_month_rounded,
            label: isCardsTab
                ? _formatYearMonthLabel(
                    _selectedYearMonthKey ?? (now.year * 100 + now.month),
                  )
                : monthLabel,
            isSelected: isCardsTab || hasMonth,
          ),
        ),
        IconButton(
          key: const Key('transactions_next_month_button'),
          tooltip: 'Próximo mês',
          visualDensity: VisualDensity.compact,
          onPressed: () => shiftMonth(1),
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
        ),
        if (!isCardsTab && hasMonth)
          ActionChip(
            key: const Key('transactions_all_months_chip'),
            label: const Text('Todos'),
            onPressed: () => setState(() {
              _selectedYearMonthKey = null;
              _selectedDay = null;
            }),
            visualDensity: VisualDensity.compact,
            backgroundColor: AppTheme.cardSurface,
            labelStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (!isCardsTab && hasDay)
          ActionChip(
            label: const Text('Mês inteiro'),
            onPressed: () => setState(() => _selectedDay = null),
            visualDensity: VisualDensity.compact,
            backgroundColor: AppTheme.cardSurface,
            labelStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryFilterChips({
    required BuildContext context,
    required List<String> categories,
    required String? selectedCategory,
  }) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        key: const Key('transactions_category_chips_scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CategoryChipPill(
              label: 'Todos',
              isSelected: selectedCategory == null,
              onTap: () => ref
                  .read(selectedCategoryFilterProvider.notifier)
                  .selectCategory(null),
            ),
            ...categories.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: _CategoryChipPill(
                  label: cat,
                  isSelected: selectedCategory == cat,
                  onTap: () => ref
                      .read(selectedCategoryFilterProvider.notifier)
                      .selectCategory(
                        selectedCategory == cat ? null : cat,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedTransactionsCard({
    required BuildContext context,
    required List<Transaction> filtered,
    required NumberFormat currencyFormatter,
    required DateFormat dateFormatter,
  }) {
    if (filtered.isEmpty) {
      return Container(
        key: const Key('transactions_empty_state_card'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: AppTheme.whiteCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 28,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhuma transação encontrada',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cadastre receitas ou despesas mesmo sem internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (_selectedYearMonthKey != null ||
                _selectedDay != null ||
                _searchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedYearMonthKey = null;
                    _selectedDay = null;
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      key: const Key('transactions_unified_list_card'),
      decoration: AppTheme.whiteCardDecoration,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(
          color: AppTheme.cardBorder,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final tx = filtered[index];
          final isIncome = tx.isIncome;
          final iconData = _categoryIcon(tx.category, isIncome: isIncome);
          final isCompact = MediaQuery.sizeOf(context).width < 600;

          final syncBadge = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: tx.isSynced
                ? AppTheme.emeraldBadgeDecoration
                : AppTheme.warningBadgeDecoration,
            child: Text(
              tx.isSynced ? 'Sincronizado' : 'Pendente local',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tx.isSynced
                    ? AppTheme.emeraldDeep
                    : AppTheme.warningDark,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          final amountText = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${isIncome ? "+" : "-"} ${currencyFormatter.format(tx.amount)}',
              maxLines: 1,
              style: TextStyle(
                color: isIncome
                    ? AppTheme.emeraldDeep
                    : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          size: 19,
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
                            const SizedBox(height: 3),
                            Text(
                              '${tx.category} · ${tx.paymentMethod} · ${dateFormatter.format(tx.date)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: amountText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 52),
                      syncBadge,
                      const Spacer(),
                      if (tx.id != null) ...[
                        IconButton(
                          key: Key('edit_transaction_button_${tx.id}'),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Editar transação',
                          onPressed: () {
                            ManualTransactionFormModal.show(
                              context,
                              initialTransaction: tx,
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: Key('delete_transaction_button_${tx.id}'),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: AppTheme.textMuted,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Excluir transação',
                          onPressed: () {
                            ref
                                .read(transactionsControllerProvider)
                                .deleteTransaction(tx.id!);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // Ícone temático por categoria
                Container(
                  width: 42,
                  height: 42,
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
                const SizedBox(width: 14),

                // Descrição + Categoria e Data
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
                       const SizedBox(height: 3),
                      Text(
                        '${tx.category} · ${tx.paymentMethod} · ${dateFormatter.format(tx.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Valor + Badge de status (Sincronizado verde / Pendente local laranja)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      amountText,
                      const SizedBox(height: 4),
                      syncBadge,
                    ],
                  ),
                ),

                if (tx.id != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: Key('edit_transaction_button_${tx.id}'),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Editar transação',
                    onPressed: () {
                      ManualTransactionFormModal.show(
                        context,
                        initialTransaction: tx,
                      );
                    },
                  ),
                  IconButton(
                    key: Key('delete_transaction_button_${tx.id}'),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: AppTheme.textMuted,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Excluir transação',
                    onPressed: () {
                      ref
                          .read(transactionsControllerProvider)
                          .deleteTransaction(tx.id!);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnifiedBillsCard({
    required BuildContext context,
    required List<Bill> filteredBills,
    required NumberFormat currencyFormatter,
    required DateFormat dateFormatter,
  }) {
    if (filteredBills.isEmpty) {
      return Container(
        key: const Key('bills_empty_state_card'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: AppTheme.whiteCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                size: 28,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhum boleto ou conta encontrada',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cadastre suas contas de consumo, aluguel, boletos ou assinaturas fixas do cartão para receber 2 lembretes diários e dar baixa em 1 toque.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('empty_state_add_bill_button'),
              onPressed: () => ManualTransactionFormModal.show(
                context,
                startInBillMode: true,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navyDark,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Cadastrar Boleto / Conta'),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('bills_unified_list_card'),
      decoration: AppTheme.whiteCardDecoration,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: filteredBills.length,
        separatorBuilder: (_, _) => const Divider(
          color: AppTheme.cardBorder,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final bill = filteredBills[index];
          final iconData = _categoryIcon(bill.category, isIncome: false);
          final isPaid = bill.isPaid;
          final isOverdue = bill.isOverdue();
          final isDueToday = bill.isDueToday();
          final daysUntil = bill.daysUntilDue();

          String dueStatusLabel;
          BoxDecoration statusDecoration;
          Color statusTextColor;

          if (isPaid) {
            dueStatusLabel = 'Pago';
            statusDecoration = AppTheme.emeraldBadgeDecoration;
            statusTextColor = AppTheme.emeraldDeep;
          } else if (isOverdue) {
            dueStatusLabel =
                'Vencido (${daysUntil.abs()}d)';
            statusDecoration = BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            );
            statusTextColor = AppTheme.errorColor;
          } else if (isDueToday) {
            dueStatusLabel = 'Vence hoje';
            statusDecoration = AppTheme.warningBadgeDecoration;
            statusTextColor = AppTheme.warningDark;
          } else {
            dueStatusLabel =
                daysUntil <= 3 ? 'Vence em ${daysUntil}d' : 'A vencer';
            statusDecoration = AppTheme.warningBadgeDecoration;
            statusTextColor = AppTheme.warningDark;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppTheme.emeraldSoftBg
                            : AppTheme.subtleSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconData,
                        size: 20,
                        color: isPaid
                            ? AppTheme.emeraldDeep
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              decoration:
                                  isPaid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${bill.category} · Vencimento: ${dateFormatter.format(bill.dueDate)}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: statusDecoration,
                                child: Text(
                                  dueStatusLabel,
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (bill.isRecurring)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.subtleSurface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppTheme.cardBorder,
                                    ),
                                  ),
                                  child: const Text(
                                    'Recorrente mensal',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (bill.isCreditCardCharge)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: AppTheme.emeraldBadgeDecoration,
                                  child: const Text(
                                    'Incluso na Fatura do Cartão',
                                    style: TextStyle(
                                      color: AppTheme.emeraldDeep,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormatter.format(bill.amount),
                          style: TextStyle(
                            color: isPaid
                                ? AppTheme.emeraldDeep
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (bill.id != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: Key('edit_bill_button_${bill.id}'),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Editar boleto',
                                onPressed: () {
                                  ManualTransactionFormModal.show(
                                    context,
                                    initialBill: bill,
                                  );
                                },
                              ),
                              IconButton(
                                key: Key('delete_bill_button_${bill.id}'),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppTheme.textMuted,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Excluir boleto',
                                onPressed: () {
                                  ref
                                      .read(transactionsControllerProvider)
                                      .deleteBill(bill.id!);
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                if (bill.hasBarcode || bill.id != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (bill.hasBarcode)
                        OutlinedButton.icon(
                          key: Key('copy_bill_barcode_${bill.id}'),
                          onPressed: () => _handleCopyBarcode(context, bill),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.cardBorder),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text(
                            'Copiar Código / PIX',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!isPaid && bill.id != null)
                        FilledButton.icon(
                          key: Key('pay_bill_button_${bill.id}'),
                          onPressed: () => _handlePayBill(context, bill),
                          style: FilledButton.styleFrom(
                            backgroundColor: bill.isCreditCardCharge
                                ? AppTheme.navyDark
                                : AppTheme.emeraldPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: Icon(
                            bill.isCreditCardCharge
                                ? Icons.credit_card_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                          ),
                          label: Text(
                            bill.isCreditCardCharge
                                ? 'Confirmar no Cartão'
                                : 'Dar Baixa / Pagar',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (isPaid && bill.id != null)
                        OutlinedButton.icon(
                          key: Key('unpay_bill_button_${bill.id}'),
                          onPressed: () => _handleUnpayBill(context, bill),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: BorderSide(
                              color: AppTheme.errorColor.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.undo_rounded, size: 15),
                          label: const Text(
                            'Estornar pagamento',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
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
    if (lower.contains('renda')) return Icons.payments_outlined;
    return Icons.receipt_long_outlined;
  }
}

class _CategoryChipPill extends StatelessWidget {
  const _CategoryChipPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.navyDark : AppTheme.cardSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppTheme.navyDark : AppTheme.cardBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateFilterChipLabel extends StatelessWidget {
  const _DateFilterChipLabel({
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  final IconData icon;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.navyDark : AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isSelected ? AppTheme.navyDark : AppTheme.cardBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.white : AppTheme.emeraldDeep,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isSelected ? Colors.white70 : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }
}
