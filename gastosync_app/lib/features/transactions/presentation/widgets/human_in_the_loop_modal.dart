import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/brl_currency_formatter.dart';
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
          backgroundColor: AppTheme.cardSurface,
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
      backgroundColor: AppTheme.cardSurface,
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
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  late TransactionType _selectedType;
  bool _isSaving = false;

  static const List<String> availableCategories = [
    'Alimentação',
    'Transporte',
    'Moradia',
    'Saúde',
    'Lazer',
    'Educação',
    'Investimentos',
    'Outros',
  ];

  static const List<String> availablePaymentMethods = [
    'PIX',
    'Débito',
    'Crédito',
    'Dinheiro',
    'Transferência',
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.prediction.normalizedDescription,
    );
    _amountController = TextEditingController(
      text: BrlCurrencyInputFormatter.formatValue(
        widget.prediction.estimatedAmount,
      ),
    );
    _selectedType = widget.initialType;
    if (_selectedType == TransactionType.income) {
      _selectedCategory = 'Renda';
    } else {
      _selectedCategory =
          availableCategories.contains(widget.prediction.category)
              ? widget.prediction.category
              : 'Outros';
    }
    _selectedPaymentMethod =
        availablePaymentMethods.contains(widget.prediction.paymentMethod)
            ? widget.prediction.paymentMethod
            : 'PIX';
    _selectedDate = widget.prediction.inferredDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount =
        BrlCurrencyInputFormatter.parseValue(_amountController.text);
    final cleanDescription = _descriptionController.text.trim();
    final effectiveDate = _selectedDate;
    final effectiveCategory = _selectedType == TransactionType.income
        ? 'Renda'
        : (_selectedCategory.toLowerCase().startsWith('renda')
            ? 'Outros'
            : _selectedCategory);

    setState(() => _isSaving = true);

    try {
      final enrichedPrediction = widget.prediction.copyWith(
        category: effectiveCategory,
        paymentMethod: _selectedPaymentMethod,
        inferredDate: effectiveDate,
        estimatedAmount: parsedAmount,
        normalizedDescription: cleanDescription,
      );

      final tx = Transaction(
        description: cleanDescription,
        amount: parsedAmount,
        date: effectiveDate,
        type: _selectedType,
        category: effectiveCategory,
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
          category: effectiveCategory,
          rawSuggestion: jsonEncode(enrichedPrediction.toJson()),
          confidenceScore: widget.prediction.confidence,
          categorySuggested: effectiveCategory,
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
    final confidencePercent = (widget.prediction.confidence * 100).round();
    final isLowConfidence = widget.prediction.isLowConfidence;
    final isOfflineFallback = widget.prediction.isOfflineFallback;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOfflineFallback
                              ? AppTheme.warningBadgeBg
                              : AppTheme.emeraldSoftBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isOfflineFallback
                              ? Icons.cloud_off_rounded
                              : Icons.auto_awesome_rounded,
                          color: isOfflineFallback
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
                              isOfflineFallback
                                  ? 'Revisão Manual (Modo Offline)'
                                  : 'Revisão Human-in-the-Loop (IA)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              widget.prediction.isFromOcr
                                  ? 'Extraído via OCR de Comprovante • Llama 3.3 70B'
                                  : 'Sugestão preditiva Llama 3.3 70B (Groq LPU) • Confiança: $confidencePercent%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
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
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.warningBannerDecoration,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warningDark,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isOfflineFallback
                                  ? (widget.prediction.fallbackReason ??
                                      'Assistente indisponível offline. Confirme os campos manualmente.')
                                  : 'Confiança baixa ($confidencePercent%). Por favor, revise atentamente os dados sugeridos.',
                              style: const TextStyle(
                                color: AppTheme.warningDark,
                                fontSize: 12,
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
                      color: AppTheme.emeraldSoftBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.emeraldBadgeBg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: AppTheme.emeraldDeep,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.prediction.budgetTip,
                            style: const TextStyle(
                              color: AppTheme.emeraldDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Seletor de Tipo (Despesa / Receita)
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TransactionType>(
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
                            _selectedCategory = 'Renda';
                          } else if (_selectedCategory == 'Renda' ||
                              !availableCategories
                                  .contains(_selectedCategory)) {
                            _selectedCategory = availableCategories.contains(
                              widget.prediction.category,
                            )
                                ? widget.prediction.category
                                : 'Alimentação';
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Campo Descrição
                  TextFormField(
                    key: const Key('hitl_description_field'),
                    controller: _descriptionController,
                    cursorColor: AppTheme.emeraldPrimary,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
                  const SizedBox(height: 12),

                  // Linha Valor + Data
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: const Key('hitl_amount_field'),
                          controller: _amountController,
                          cursorColor: AppTheme.emeraldPrimary,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            BrlCurrencyInputFormatter(),
                          ],
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Valor (R\$)',
                            hintText: '0,00',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money_rounded),
                          ),
                          validator: (value) {
                            final parsed =
                                BrlCurrencyInputFormatter.parseValue(value);
                            if (parsed <= 0) {
                              return 'O valor deve ser maior que zero.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          key: const Key('hitl_date_selector'),
                          onTap: _isSaving ? null : _selectDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                            ),
                            child: Text(
                              dateFmt.format(_selectedDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Linha Categoria + Forma de Pagamento
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: Key('hitl_category_dropdown_${_selectedType.name}'),
                          isExpanded: true,
                          initialValue: _selectedType == TransactionType.income
                              ? 'Renda'
                              : _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined, size: 18),
                          ),
                          items: (_selectedType == TransactionType.income
                                  ? const <String>['Renda']
                                  : availableCategories)
                              .map(
                                (cat) => DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(
                                    cat,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _selectedType == TransactionType.income
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _selectedCategory = value);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('hitl_payment_method_dropdown'),
                          isExpanded: true,
                          initialValue: _selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Pagamento',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.credit_card_rounded, size: 18),
                          ),
                          items: availablePaymentMethods
                              .map(
                                (method) => DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(
                                    method,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedPaymentMethod = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
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
        },
      ),
    );
  }
}
