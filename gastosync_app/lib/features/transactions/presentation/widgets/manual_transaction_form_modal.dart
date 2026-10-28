import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/brl_currency_formatter.dart';
import '../../../budget_agent/data/services/budget_agent_service.dart';
import '../../../budget_agent/domain/models/agent_prediction_models.dart';
import '../../../dashboard/presentation/widgets/quick_expense_input_field.dart';
import '../../domain/models/transaction.dart';
import '../controllers/transactions_controller.dart';

class ManualTransactionFormModal extends ConsumerStatefulWidget {
  const ManualTransactionFormModal({super.key});

  static Future<bool?> show(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppTheme.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const ManualTransactionFormModal(),
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
  final _smartInputController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Alimentação';
  String _selectedPaymentMethod = 'PIX';
  DateTime _selectedDate = DateTime.now();

  static const List<String> _paymentMethods = [
    'PIX',
    'Débito',
    'Crédito',
    'Dinheiro',
    'Transferência',
  ];

  final List<String> _categories = [
    'Alimentação',
    'Moradia',
    'Transporte',
    'Lazer',
    'Saúde',
  ];

  static bool _isRendaCategory(String category) {
    final lower = category.trim().toLowerCase();
    return lower == 'renda' || lower.startsWith('renda ');
  }

  AgentPredictionResponse? _lastAiPrediction;
  bool _isSubmitting = false;
  bool _isPredictingAi = false;
  bool _isProcessingOcr = false;

  @override
  void dispose() {
    _smartInputController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _applyPredictionToFields(AgentPredictionResponse prediction) {
    setState(() {
      _lastAiPrediction = prediction;
      if (prediction.normalizedDescription.trim().isNotEmpty) {
        _descriptionController.text = prediction.normalizedDescription.trim();
      }
      if (prediction.estimatedAmount > 0) {
        _amountController.text =
            BrlCurrencyInputFormatter.formatValue(prediction.estimatedAmount);
      }
      if (_selectedType == TransactionType.income) {
        _selectedCategory = 'Renda';
      } else {
        final cat = prediction.category.trim();
        if (cat.isNotEmpty && !_isRendaCategory(cat)) {
          if (!_categories.contains(cat)) {
            _categories.add(cat);
          }
          _selectedCategory = cat;
        } else if (_isRendaCategory(_selectedCategory)) {
          _selectedCategory = 'Alimentação';
        }
      }
      if (_paymentMethods.contains(prediction.paymentMethod)) {
        _selectedPaymentMethod = prediction.paymentMethod;
      }
      if (prediction.inferredDate != null) {
        _selectedDate = prediction.inferredDate!;
      }
    });
  }

  Future<void> _fillWithAi() async {
    final rawText = _smartInputController.text.trim().isNotEmpty
        ? _smartInputController.text.trim()
        : _descriptionController.text.trim();

    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Digite uma frase no campo de Entrada inteligente (ex: "Almoço 45,90 no débito").',
          ),
        ),
      );
      return;
    }

    final parsedAmount =
        BrlCurrencyInputFormatter.parseValue(_amountController.text);
    final explicitAmount = parsedAmount > 0 ? parsedAmount : null;

    setState(() => _isPredictingAi = true);
    try {
      final agentService = ref.read(budgetAgentServiceProvider);
      final prediction = await agentService.predictCategoryWithFallback(
        rawInput: rawText,
        explicitAmount: explicitAmount,
      );

      if (!mounted) return;
      _applyPredictionToFields(prediction);
    } finally {
      if (mounted) {
        setState(() => _isPredictingAi = false);
      }
    }
  }

  Future<void> _fillWithOcr() async {
    setState(() => _isProcessingOcr = true);
    try {
      final picker = ref.read(receiptImagePickerProvider);
      final picked = await picker.pickReceipt(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final agentService = ref.read(budgetAgentServiceProvider);
      final prediction = await agentService.extractReceiptFromOcrWithFallback(
        imageBytes: picked.bytes,
        fileName: picked.fileName,
      );

      if (!mounted) return;
      _applyPredictionToFields(prediction);
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  Future<void> _promptNewCategory() async {
    final controller = TextEditingController();
    final newCat = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex: Educação, Investimentos, Pets...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (newCat != null && newCat.isNotEmpty && mounted) {
      if (_isRendaCategory(newCat)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "A categoria 'Renda' é exclusiva para Receitas e não pode ser usada em Despesas.",
            ),
          ),
        );
        return;
      }
      setState(() {
        final exists = _categories.any(
          (c) => c.toLowerCase() == newCat.toLowerCase(),
        );
        if (!exists) {
          _categories.add(newCat);
        }
        _selectedCategory = newCat;
      });

      // Persiste imediatamente a nova categoria em LocalBudgets para aparecer em Planejamento
      await ref.read(appDatabaseProvider).ensureCategoryBudgetExists(
            newCat,
            defaultLimit: 500.0,
          );
    }
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

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        BrlCurrencyInputFormatter.parseValue(_amountController.text);
    final description = _descriptionController.text.trim();
    final effectiveCategory = _selectedType == TransactionType.income
        ? 'Renda'
        : (_isRendaCategory(_selectedCategory)
            ? 'Alimentação'
            : _selectedCategory);

    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(transactionsControllerProvider);
      final prediction = _lastAiPrediction;

      if (prediction != null) {
        await controller.createAiConfirmedTransaction(
          description: description,
          amount: amount,
          date: _selectedDate,
          type: _selectedType,
          category: effectiveCategory,
          rawSuggestion: jsonEncode(prediction.toJson()),
          confidenceScore: prediction.confidence,
          categorySuggested: effectiveCategory,
          budgetTip: prediction.budgetTip,
        );
      } else {
        await controller.createManualTransaction(
          description: description,
          amount: amount,
          date: _selectedDate,
          type: _selectedType,
          category: effectiveCategory,
        );
      }

      if (_selectedType == TransactionType.expense) {
        await ref.read(appDatabaseProvider).ensureCategoryBudgetExists(
              effectiveCategory,
              defaultLimit: 500.0,
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return isToday ? 'Hoje, $formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSubmitting || _isPredictingAi || _isProcessingOcr;
    final budgets = ref.watch(watchBudgetsProvider).value ?? const <LocalBudget>[];
    final transactions =
        ref.watch(watchTransactionsProvider).value ?? const <Transaction>[];

    // Unifica categorias de despesa (nunca inclui 'Renda')
    final categoryMap = <String, String>{};
    for (final c in _categories) {
      final trimmed = c.trim();
      if (trimmed.isNotEmpty && !_isRendaCategory(trimmed)) {
        categoryMap[trimmed.toLowerCase()] = trimmed;
      }
    }
    for (final b in budgets) {
      final trimmed = b.category.trim();
      if (trimmed.isNotEmpty && !_isRendaCategory(trimmed)) {
        categoryMap.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
      }
    }
    for (final t in transactions) {
      if (t.isExpense) {
        final trimmed = t.category.trim();
        if (trimmed.isNotEmpty && !_isRendaCategory(trimmed)) {
          categoryMap.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
        }
      }
    }
    final allExpenseCategories = categoryMap.values.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: NOVO LANÇAMENTO / Adicionar transação
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOVO LANÇAMENTO',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Adicionar transação',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      isBusy ? null : () => Navigator.of(context).pop(false),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bloco superior: Entrada inteligente (IA + OCR)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppTheme.emeraldPrimary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Entrada inteligente',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('smart_input_text_field'),
                    controller: _smartInputController,
                    enabled: !isBusy,
                    cursorColor: AppTheme.emeraldPrimary,
                    onSubmitted: (_) => _fillWithAi(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "Ex: 'Almoço 45,90 no débito'...",
                      hintStyle: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('manual_ai_suggest_button'),
                          onPressed: isBusy ? null : _fillWithAi,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppTheme.cardSurface,
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isPredictingAi
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: AppTheme.emeraldPrimary,
                                ),
                          label: const Text(
                            'Preencher com IA',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const Key('manual_ocr_button'),
                        onPressed: isBusy ? null : _fillWithOcr,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.cardSurface,
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.cardBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isProcessingOcr
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                        label: const Text(
                          'OCR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_lastAiPrediction != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldSoftBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.emeraldBadgeBg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                                color: AppTheme.emeraldDeep,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Human-in-the-Loop (Llama 3.3 70B): $_selectedCategory • $_selectedPaymentMethod • ${_formatSelectedDate(_selectedDate)}',
                                  style: const TextStyle(
                                    color: AppTheme.emeraldDeep,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lastAiPrediction!.budgetTip,
                            style: const TextStyle(
                              color: AppTheme.emeraldDeep,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Abas Despesa / Receita
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeTabButton(
                      key: const Key('tab_expense_button'),
                      label: 'Despesa',
                      isSelected: _selectedType == TransactionType.expense,
                      selectedColor: AppTheme.navyDark,
                      onTap: () {
                        setState(() {
                          _selectedType = TransactionType.expense;
                          if (_selectedCategory == 'Renda') {
                            _selectedCategory = 'Alimentação';
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _TypeTabButton(
                      key: const Key('tab_income_button'),
                      label: 'Receita',
                      isSelected: _selectedType == TransactionType.income,
                      selectedColor: AppTheme.emeraldPrimary,
                      onTap: () {
                        setState(() {
                          _selectedType = TransactionType.income;
                          _selectedCategory = 'Renda';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Campo Valor R$ 0,00 (apenas números, formatado no padrão Real Brasileiro)
            const Text(
              'Valor',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('manual_amount_field'),
              controller: _amountController,
              cursorColor: AppTheme.emeraldPrimary,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                BrlCurrencyInputFormatter(),
              ],
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '0,00',
                hintStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                filled: true,
                fillColor: AppTheme.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.emeraldPrimary,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                final parsed = BrlCurrencyInputFormatter.parseValue(value);
                if (parsed <= 0) {
                  return 'Informe um valor maior que zero.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Campo Descrição
            const Text(
              'Descrição',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('manual_description_field'),
              controller: _descriptionController,
              cursorColor: AppTheme.emeraldPrimary,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Nome da transação (ex: Supermercado, Aluguel)',
                hintStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppTheme.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'A descrição não pode ser vazia.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Categoria: Receita só pode ser 'Renda'; Despesa nunca pode ser 'Renda'
            const Text(
              'Categoria',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedType == TransactionType.income)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('category_chip_Renda'),
                    label: const Text('Renda'),
                    selected: true,
                    showCheckmark: false,
                    selectedColor: AppTheme.emeraldPrimary,
                    backgroundColor: AppTheme.emeraldPrimary,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) {},
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...allExpenseCategories.map((cat) {
                    final isSelected =
                        _selectedCategory.toLowerCase() == cat.toLowerCase();
                    return ChoiceChip(
                      key: Key('category_chip_$cat'),
                      label: Text(cat),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: AppTheme.navyDark,
                      backgroundColor: AppTheme.cardSurface,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    );
                  }),
                  ActionChip(
                    key: const Key('add_custom_category_chip'),
                    backgroundColor: AppTheme.emeraldSoftBg,
                    side: const BorderSide(color: AppTheme.emeraldBadgeBg),
                    label: const Text(
                      '+ Nova Categoria',
                      style: TextStyle(
                        color: AppTheme.emeraldDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: isBusy ? null : _promptNewCategory,
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Forma de Pagamento (extraída pela IA ou selecionada manualmente)
            const Text(
              'Forma de Pagamento',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return ChoiceChip(
                  key: Key('payment_method_chip_$method'),
                  label: Text(method),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: AppTheme.emeraldPrimary,
                  backgroundColor: AppTheme.cardSurface,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedPaymentMethod = method);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Seletor de Data
            const Text(
              'Data',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              key: const Key('manual_date_selector'),
              borderRadius: BorderRadius.circular(12),
              onTap: isBusy ? null : _selectDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatSelectedDate(_selectedDate),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Botão largo inferior verde "Confirmar e Salvar"
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('manual_save_button'),
                onPressed: isBusy ? null : _confirmAndSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emeraldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirmar e Salvar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTabButton extends StatelessWidget {
  const _TypeTabButton({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
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
