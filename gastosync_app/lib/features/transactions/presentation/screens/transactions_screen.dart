import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/csv_export_service.dart';
import '../../../../core/theme/app_theme.dart';
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
  int? _selectedYearMonthKey;
  int? _selectedDay;

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

          // Filtra transações por categoria, mês/dia e termo de pesquisa
          final query = _searchQuery.trim().toLowerCase();
          final filteredTransactions = transactions.where((tx) {
            final matchesMonth = _selectedYearMonthKey == null ||
                (tx.date.year * 100 + tx.date.month) == _selectedYearMonthKey;
            if (!matchesMonth) return false;

            final matchesDay =
                _selectedDay == null || tx.date.day == _selectedDay;
            if (!matchesDay) return false;

            final matchesCategory = selectedCategory == null ||
                tx.category.toLowerCase() == selectedCategory.toLowerCase() ||
                (selectedCategory == 'Renda' && tx.isIncome);

            if (!matchesCategory) return false;
            if (query.isEmpty) return true;

            return tx.description.toLowerCase().contains(query) ||
                tx.category.toLowerCase().contains(query);
          }).toList();

          // Filtra boletos por categoria, mês/dia e termo de pesquisa
          final filteredBills = bills.where((bill) {
            final matchesMonth = _selectedYearMonthKey == null ||
                (bill.dueDate.year * 100 + bill.dueDate.month) ==
                    _selectedYearMonthKey;
            if (!matchesMonth) return false;

            final matchesDay =
                _selectedDay == null || bill.dueDate.day == _selectedDay;
            if (!matchesDay) return false;

            final matchesCategory = selectedCategory == null ||
                bill.category.toLowerCase() == selectedCategory.toLowerCase();
            if (!matchesCategory) return false;
            if (query.isEmpty) return true;

            return bill.description.toLowerCase().contains(query) ||
                bill.category.toLowerCase().contains(query) ||
                bill.barcode.toLowerCase().contains(query);
          }).toList();

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

                // 2. Seletor segmentado ("Lançamentos" | "Boletos a Pagar") (T016)
                _buildSubTabSelector(
                  selectedSubTab: selectedSubTab,
                  transactionsCount: transactions.length,
                  pendingBillsCount: pendingBillsCount,
                ),
                const SizedBox(height: 16),

                if (selectedSubTab == 1) ...[
                  // Resumo de Boletos separando Total Real a Pagar (!isCreditCardCharge)
                  // de Lembretes no Cartão (Inclusos na Fatura) (isCreditCardCharge) (T016)
                  _buildBillsSummarySection(
                    context: context,
                    bills: bills,
                    currencyFormatter: currencyFormatter,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Barra de pesquisa
                _buildSearchBar(selectedSubTab: selectedSubTab),
                const SizedBox(height: 12),

                // 3b. Filtro por Mês e Dia (Web e Mobile)
                _buildDateFilterBar(
                  context: context,
                  availableYearMonths: availableYearMonths,
                ),
                const SizedBox(height: 12),

                // 4. Chips horizontais de categoria sem scrollbar visível
                _buildCategoryFilterChips(
                  context: context,
                  categories: categories,
                  selectedCategory: selectedCategory,
                ),
                const SizedBox(height: 18),

                // 5. Card unificado listando as transações ou os boletos
                if (selectedSubTab == 0)
                  _buildUnifiedTransactionsCard(
                    context: context,
                    filtered: filteredTransactions,
                    currencyFormatter: currencyFormatter,
                    dateFormatter: dateFormatter,
                  )
                else
                  _buildUnifiedBillsCard(
                    context: context,
                    filteredBills: filteredBills,
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
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                    fontSize: 13,
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
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                        'Boletos a Pagar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedSubTab == 1
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: selectedSubTab == 1
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (pendingBillsCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
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
                            fontSize: 11,
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
        ],
      ),
    );
  }

  Widget _buildBillsSummarySection({
    required BuildContext context,
    required List<Bill> bills,
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
              const Expanded(
                child: Text(
                  'TOTAL REAL A PAGAR (CAIXA)',
                  style: TextStyle(
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
  }) {
    final now = DateTime.now();
    final hasMonth = _selectedYearMonthKey != null;
    final hasDay = _selectedDay != null;
    final monthLabel = hasMonth
        ? _formatYearMonthLabel(_selectedYearMonthKey!)
        : 'Mês: Todos';
    final dayLabel = hasDay
        ? 'Dia ${_selectedDay!.toString().padLeft(2, '0')}'
        : 'Dia: Todos';

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

    final mq = MediaQuery.of(context);
    final usableHeight =
        mq.size.height - mq.viewPadding.top - mq.viewPadding.bottom;
    final menuMaxHeight = math.max(180.0, math.min(320.0, usableHeight * 0.42));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<int>(
          key: const Key('transactions_month_filter_button'),
          tooltip: 'Filtrar por mês',
          color: AppTheme.cardSurface,
          position: PopupMenuPosition.under,
          constraints: BoxConstraints(maxHeight: menuMaxHeight),
          onSelected: (value) {
            setState(() {
              _selectedYearMonthKey = value == 0 ? null : value;
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem<int>(
              value: 0,
              child: Text(
                'Todos os meses',
                style: TextStyle(
                  fontWeight: !hasMonth ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const PopupMenuDivider(),
            ...availableYearMonths.map(
              (ym) => PopupMenuItem<int>(
                value: ym,
                child: Text(
                  _formatYearMonthLabel(ym),
                  style: TextStyle(
                    fontWeight: _selectedYearMonthKey == ym
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          child: _DateFilterChipLabel(
            icon: Icons.calendar_month_rounded,
            label: monthLabel,
            isSelected: hasMonth,
          ),
        ),
        PopupMenuButton<int>(
          key: const Key('transactions_day_filter_button'),
          tooltip: 'Filtrar por dia',
          color: AppTheme.cardSurface,
          position: PopupMenuPosition.under,
          constraints: BoxConstraints(maxHeight: menuMaxHeight),
          onSelected: (value) async {
            if (value == 0) {
              setState(() => _selectedDay = null);
            } else if (value == -2) {
              setState(() {
                _selectedYearMonthKey = now.year * 100 + now.month;
                _selectedDay = now.day;
              });
            } else if (value == -1) {
              await pickDateFromCalendar();
            } else {
              setState(() => _selectedDay = value);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<int>(
              value: 0,
              child: Text(
                'Todos os dias',
                style: TextStyle(
                  fontWeight: !hasDay ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            PopupMenuItem<int>(
              value: -2,
              child: Text('Hoje (${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')})'),
            ),
            const PopupMenuItem<int>(
              value: -1,
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 16, color: AppTheme.emeraldDeep),
                  SizedBox(width: 8),
                  Text('Escolher no calendário...'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            ...List.generate(
              31,
              (index) {
                final day = index + 1;
                return PopupMenuItem<int>(
                  value: day,
                  child: Text(
                    'Dia ${day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: _selectedDay == day
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
          child: _DateFilterChipLabel(
            icon: Icons.today_rounded,
            label: dayLabel,
            isSelected: hasDay,
          ),
        ),
        if (hasMonth || hasDay)
          ActionChip(
            key: const Key('transactions_clear_date_filter_button'),
            avatar: const Icon(
              Icons.close_rounded,
              size: 15,
              color: AppTheme.textSecondary,
            ),
            label: const Text(
              'Limpar data',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppTheme.subtleSurface,
            side: const BorderSide(color: AppTheme.cardBorder),
            shape: const StadiumBorder(),
            onPressed: () {
              setState(() {
                _selectedYearMonthKey = null;
                _selectedDay = null;
              });
            },
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
                if (bill.hasBarcode || (!isPaid && bill.id != null)) ...[
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
