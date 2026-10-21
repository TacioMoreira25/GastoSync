import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../budget_agent/domain/models/agent_prediction_models.dart';
import '../../domain/models/transaction.dart';
import '../controllers/transactions_controller.dart';

class HumanInTheLoopModal extends ConsumerStatefulWidget {
  const HumanInTheLoopModal({
    required this.prediction,
    this.initialType = TransactionType.expense,
    this.onConfirmed,
    super.key,
  });

  final AgentPredictionResponse prediction;
  final TransactionType initialType;
  final ValueChanged<Transaction>? onConfirmed;

  /// Exibe o modal de forma adaptativa: BottomSheet em telas compactas (< 600dp) e Dialog em telas amplas (FR-005)
  static Future<bool?> show(
    BuildContext context, {
    required AgentPredictionResponse prediction,
    TransactionType initialType = TransactionType.expense,
    ValueChanged<Transaction>? onConfirmed,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: HumanInTheLoopModal(
              prediction: prediction,
              initialType: initialType,
              onConfirmed: onConfirmed,
            ),
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
        child: HumanInTheLoopModal(
          prediction: prediction,
          initialType: initialType,
          onConfirmed: onConfirmed,
        ),
      ),
    );
  }

  @override
  ConsumerState<HumanInTheLoopModal> createState() =>
      _HumanInTheLoopModalState();
}

class _HumanInTheLoopModalState extends ConsumerState<HumanInTheLoopModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late String _selectedCategory;
  late TransactionType _selectedType;
  bool _isSaving = false;

  static const List<String> availableCategories = [
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

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.prediction.normalizedDescription,
    );
    _amountController = TextEditingController(
      text: widget.prediction.estimatedAmount > 0
          ? widget.prediction.estimatedAmount.toStringAsFixed(2)
          : '',
    );
    _selectedCategory =
        availableCategories.contains(widget.prediction.category)
            ? widget.prediction.category
            : 'Outros';
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = _amountController.text.trim().replaceAll(',', '.');
    final parsedAmount = double.tryParse(rawAmount) ?? 0.0;
    final cleanDescription = _descriptionController.text.trim();
    final effectiveDate = widget.prediction.inferredDate ?? DateTime.now();

    setState(() => _isSaving = true);

    try {
      final tx = Transaction(
        description: cleanDescription,
        amount: parsedAmount,
        date: effectiveDate,
        type: _selectedType,
        category: _selectedCategory,
      );

      if (widget.onConfirmed != null) {
        widget.onConfirmed!(tx);
      } else {
        final controller = ref.read(transactionsControllerProvider);
        await controller.createAiConfirmedTransaction(
          description: cleanDescription,
          amount: parsedAmount,
          date: effectiveDate,
          type: _selectedType,
          category: _selectedCategory,
          rawSuggestion: jsonEncode(widget.prediction.toJson()),
          confidenceScore: widget.prediction.confidence,
          categorySuggested: widget.prediction.category,
          budgetTip: widget.prediction.budgetTip,
        );
      }

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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidencePercent = (widget.prediction.confidence * 100).round();
    final isLowConfidence = widget.prediction.isLowConfidence;
    final isOfflineFallback = widget.prediction.isOfflineFallback;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOfflineFallback
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isOfflineFallback
                        ? Icons.cloud_off_rounded
                        : Icons.auto_awesome_rounded,
                    color: isOfflineFallback
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOfflineFallback
                            ? 'Revisão Manual (Modo Offline)'
                            : 'Revisão Human-in-the-Loop (IA)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.prediction.isFromOcr
                            ? 'Extraído via OCR de Comprovante'
                            : 'Sugestão preditiva Llama 3.3 • Confiança: $confidencePercent%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Alerta de baixa confiança (< 50%) ou fallback offline (Edge Case spec.md)
            if (isLowConfidence || isOfflineFallback)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOfflineFallback
                            ? (widget.prediction.fallbackReason ??
                                'Assistente indisponível offline. Confirme os campos manualmente.')
                            : 'Confiança baixa ($confidencePercent%). Por favor, revise atentamente a categoria sugerida.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Dica Orçamentária da IA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.prediction.budgetTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seletor de Tipo (Despesa / Receita)
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
                setState(() => _selectedType = selection.first);
              },
            ),
            const SizedBox(height: 16),

            // Campo Descrição
            TextFormField(
              key: const Key('hitl_description_field'),
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe uma descrição válida.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Campo Valor
            TextFormField(
              key: const Key('hitl_amount_field'),
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
                  return 'O valor deve ser maior que zero.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Seletor de Categoria
            DropdownButtonFormField<String>(
              key: const Key('hitl_category_dropdown'),
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: availableCategories
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
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('hitl_cancel_button'),
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('hitl_confirm_button'),
                  onPressed: _isSaving ? null : _handleConfirm,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirmar e Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
