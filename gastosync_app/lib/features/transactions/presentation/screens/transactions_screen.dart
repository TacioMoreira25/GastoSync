import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/transaction.dart';
import '../controllers/transactions_controller.dart';
import '../widgets/manual_transaction_form_modal.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transações (Offline-First)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: Icon(
                Icons.storage_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: const Text('Drift SQLite Ativo'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_transaction_fab'),
        onPressed: () => ManualTransactionFormModal.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Transação'),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Erro ao carregar transações locais: $err'),
        ),
        data: (transactions) {
          final filtered = selectedCategory == null
              ? transactions
              : transactions
                  .where((t) => t.category == selectedCategory)
                  .toList();

          final netBalance =
              TransactionCalculations.calculateNetBalance(transactions);
          final totalIncome =
              TransactionCalculations.calculateTotalIncome(transactions);
          final totalExpense =
              TransactionCalculations.calculateTotalExpense(transactions);

          final categories = <String>{
            for (final t in transactions) t.category,
          }.toList()
            ..sort();

          return Column(
            children: [
              // Resumo superior instantâneo (Stream-driven)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Saldo Líquido',
                          value: currencyFormatter.format(netBalance),
                          color: netBalance >= 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        _SummaryItem(
                          label: 'Total Receitas',
                          value: currencyFormatter.format(totalIncome),
                          color: const Color(0xFF16A34A),
                        ),
                        _SummaryItem(
                          label: 'Total Despesas',
                          value: currencyFormatter.format(totalExpense),
                          color: theme.colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (categories.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: const Text('Todas'),
                          selected: selectedCategory == null,
                          onSelected: (_) => ref
                              .read(selectedCategoryFilterProvider.notifier)
                              .selectCategory(null),
                        ),
                      ),
                      ...categories.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(cat),
                            selected: selectedCategory == cat,
                            onSelected: (_) => ref
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

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma transação registrada',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Cadastre receitas ou despesas mesmo sem internet. Os dados são salvos instantaneamente no SQLite local.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          final isIncome = tx.isIncome;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isIncome
                                    ? const Color(0xFF16A34A)
                                        .withValues(alpha: 0.12)
                                    : theme.colorScheme.error
                                        .withValues(alpha: 0.12),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: isIncome
                                      ? const Color(0xFF16A34A)
                                      : theme.colorScheme.error,
                                ),
                              ),
                              title: Text(
                                tx.description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${tx.category} • ${dateFormatter.format(tx.date)} • ${tx.isSynced ? "Sincronizado" : "Local (Offline)"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${isIncome ? "+" : "-"} ${currencyFormatter.format(tx.amount)}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isIncome
                                          ? const Color(0xFF16A34A)
                                          : theme.colorScheme.error,
                                    ),
                                  ),
                                  if (tx.id != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                      ),
                                      tooltip: 'Excluir transação',
                                      onPressed: () {
                                        ref
                                            .read(
                                              transactionsControllerProvider,
                                            )
                                            .deleteTransaction(tx.id!);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
