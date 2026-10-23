import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final budgets = ref.watch(watchBudgetsProvider).value ?? const <LocalBudget>[];
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

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

          // Combina categorias padrão + metas criadas no Planejamento + categorias das transações (sem duplicar)
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
          final categories = categoryMap.values.toList();

          // Filtra por categoria selecionada e termo de pesquisa
          final query = _searchQuery.trim().toLowerCase();
          final filtered = transactions.where((tx) {
            final matchesCategory = selectedCategory == null ||
                tx.category.toLowerCase() == selectedCategory.toLowerCase() ||
                (selectedCategory == 'Renda' && tx.isIncome);

            if (!matchesCategory) return false;
            if (query.isEmpty) return true;

            return tx.description.toLowerCase().contains(query) ||
                tx.category.toLowerCase().contains(query);
          }).toList();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28.0 : 16.0,
              isDesktop ? 24.0 : 16.0,
              isDesktop ? 28.0 : 16.0,
              96.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cabeçalho MOVIMENTAÇÕES + Badge verde "X sincronizadas"
                _buildHeaderSection(
                  context: context,
                  syncedCount: syncedCount,
                  pendingCount: pendingCount,
                  totalCount: transactions.length,
                  isDesktop: isDesktop,
                ),
                const SizedBox(height: 16),

                // 2. Barra de pesquisa ("Pesquisar transações, categorias...")
                _buildSearchBar(),
                const SizedBox(height: 14),

                // 3. Chips horizontais de categoria sem scrollbar visível
                _buildCategoryFilterChips(
                  context: context,
                  categories: categories,
                  selectedCategory: selectedCategory,
                ),
                const SizedBox(height: 18),

                // 4. Card unificado listando as transações
                _buildUnifiedTransactionsCard(
                  context: context,
                  filtered: filtered,
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
    required bool isDesktop,
  }) {
    final badgeLabel = '$syncedCount sincronizada${syncedCount == 1 ? '' : 's'}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
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
                'Transações',
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
        // Badge verde "X sincronizadas" conforme protótipo Figma (FR-014)
        Container(
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
        ),
        if (pendingCount > 0) ...[
          const SizedBox(width: 8),
          Container(
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
          ),
        ],
        if (isDesktop) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const Key('add_transaction_fab'),
            onPressed: () => ManualTransactionFormModal.show(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nova Transação'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBar() {
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
          hintText: 'Pesquisar transações, categorias...',
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
              'Cadastre receitas ou despesas mesmo sem internet. Os dados são salvos instantaneamente no SQLite local.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
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
                        '${tx.category} · ${dateFormatter.format(tx.date)}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? "+" : "-"} ${currencyFormatter.format(tx.amount)}',
                      style: TextStyle(
                        color: isIncome
                            ? AppTheme.emeraldDeep
                            : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
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

                if (tx.id != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
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
