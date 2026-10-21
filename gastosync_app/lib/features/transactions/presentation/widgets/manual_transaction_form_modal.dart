import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../budget_agent/data/services/budget_agent_service.dart';
import '../../domain/models/transaction.dart';
import '../controllers/transactions_controller.dart';
import 'human_in_the_loop_modal.dart';

class ManualTransactionFormModal extends ConsumerStatefulWidget {
  const ManualTransactionFormModal({super.key});

  static Future<bool?> show(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const ManualTransactionFormModal(),
          ),
        ),
      );
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const ManualTransactionFormModal(),
      ),
    );
  }

  @override
  ConsumerState<ManualTransactionFormModal> createState() =>
      _ManualTransactionFormModalState();
}

class _ManualTransactionFormModalState
    extends ConsumerState<ManualTransactionFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Alimentação';
  bool _isSubmitting = false;
  bool _isPredictingAi = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveDirectlyOffline() async {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.parse(rawAmount);
    final description = _descriptionController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await ref.read(transactionsControllerProvider).createManualTransaction(
            description: description,
            amount: amount,
            date: DateTime.now(),
            type: _selectedType,
            category: _selectedCategory,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar transação: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _categorizeWithAi() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite uma descrição ou frase informal para consultar a IA.'),
        ),
      );
      return;
    }

    final rawAmount = _amountController.text.trim().replaceAll(',', '.');
    final explicitAmount = double.tryParse(rawAmount);

    setState(() => _isPredictingAi = true);
    try {
      final agentService = ref.read(budgetAgentServiceProvider);
      final prediction = await agentService.predictCategoryWithFallback(
        rawInput: description,
        explicitAmount: explicitAmount,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      await HumanInTheLoopModal.show(
        context,
        prediction: prediction,
        initialType: _selectedType,
      );
    } finally {
      if (mounted) {
        setState(() => _isPredictingAi = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nova Transação (Offline-First)',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Salve diretamente no banco local SQLite (Drift) ou peça categorização preditiva da IA.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedType = selection.first;
                  if (_selectedType == TransactionType.income) {
                    _selectedCategory = 'Renda Principal';
                  } else if (_selectedCategory.startsWith('Renda')) {
                    _selectedCategory = 'Alimentação';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('manual_description_field'),
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (ex: Almoço executivo, Salário)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'A descrição não pode ser vazia.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('manual_amount_field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              validator: (value) {
                final raw = (value ?? '').trim().replaceAll(',', '.');
                final parsed = double.tryParse(raw);
                if (parsed == null || parsed <= 0) {
                  return 'Informe um valor maior que zero.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('manual_category_dropdown'),
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: HumanInTheLoopModalStateCategories.list
                  .map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('manual_ai_suggest_button'),
                    onPressed: (_isSubmitting || _isPredictingAi)
                        ? null
                        : _categorizeWithAi,
                    icon: _isPredictingAi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Sugerir com IA'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('manual_save_button'),
                    onPressed: (_isSubmitting || _isPredictingAi)
                        ? null
                        : _saveDirectlyOffline,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar Local'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HumanInTheLoopModalStateCategories {
  static const List<String> list = [
    'Alimentação',
    'Transporte',
    'Moradia',
    'Saúde',
    'Lazer',
    'Educação',
    'Renda Principal',
    'Renda Extra',
    'Investimentos',
    'Outros',
  ];
}
