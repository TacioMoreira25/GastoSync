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
import '../../domain/models/bill.dart';
import '../../domain/models/transaction.dart';
import '../controllers/transactions_controller.dart';

class ManualTransactionFormModal extends ConsumerStatefulWidget {
  const ManualTransactionFormModal({
    this.startInBillMode = false,
    super.key,
  });

  final bool startInBillMode;

  static Future<bool?> show(
    BuildContext context, {
    bool startInBillMode = false,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppTheme.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ManualTransactionFormModal(
              startInBillMode: startInBillMode,
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
        child: ManualTransactionFormModal(
          startInBillMode: startInBillMode,
        ),
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
  final _barcodeController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  bool _isBillMode = false;
  bool _isRecurring = false;
  bool _isCreditCardCharge = false;
  String _selectedCategory = 'Alimentação';
  String _selectedPaymentMethod = 'PIX';
  DateTime _selectedDate = DateTime.now();

  static const List<String> _paymentMethods = [
    'PIX',
    'Débito',
    'Crédito',
    'Dinheiro',
    'Transferência',
    'Boleto',
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

  /// Cores explícitas dos switches de boleto (visíveis tanto ligados quanto desligados)
  static final WidgetStateProperty<Color?> _billSwitchThumbColor =
      WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppTheme.cardBorder;
    return states.contains(WidgetState.selected)
        ? Colors.white
        : AppTheme.textMuted;
  });

  static final WidgetStateProperty<Color?> _billSwitchTrackColor =
      WidgetStateProperty.resolveWith((states) {
    return states.contains(WidgetState.selected)
        ? AppTheme.emeraldPrimary
        : AppTheme.cardSurface;
  });

  static final WidgetStateProperty<Color?> _billSwitchOutlineColor =
      WidgetStateProperty.resolveWith((states) {
    return states.contains(WidgetState.selected)
        ? AppTheme.emeraldPrimary
        : AppTheme.textMuted;
  });

  @override
  void initState() {
    super.initState();
    _isBillMode = widget.startInBillMode;
    if (_isBillMode) {
      _selectedType = TransactionType.expense;
      _selectedCategory = 'Moradia';
    }
  }

  @override
  void dispose() {
    _smartInputController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pasteBarcodeFromClipboard() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    setState(() {
      _barcodeController.text = text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Linha digitável / código PIX colado com sucesso.'),
      ),
    );
  }

  Future<void> _copyBarcodeToClipboard() async {
    final text = _barcodeController.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Linha digitável / código PIX copiado!'),
      ),
    );
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
    final effectiveCategory =
        (!_isBillMode && _selectedType == TransactionType.income)
            ? 'Renda'
            : (_isRendaCategory(_selectedCategory)
                ? 'Alimentação'
                : _selectedCategory);

    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(transactionsControllerProvider);

      if (_isBillMode) {
        await controller.createBill(
          description: description,
          amount: amount,
          dueDate: _selectedDate,
          category: effectiveCategory,
          barcode: _barcodeController.text.trim(),
          isRecurring: _isRecurring,
          isCreditCardCharge: _isCreditCardCharge,
        );
      } else {
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
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar lançamento: $e')),
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
    final bills = ref.watch(watchBillsProvider).value ?? const <Bill>[];

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
    for (final bill in bills) {
      if (!bill.isDeleted) {
        final trimmed = bill.category.trim();
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
            // Cabeçalho: NOVO LANÇAMENTO / Adicionar transação ou boleto
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOVO LANÇAMENTO',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isBillMode
                            ? 'Adicionar boleto / conta'
                            : 'Adicionar transação',
                        style: const TextStyle(
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
                                  _lastAiPrediction!.isOfflineFallback
                                      ? 'Preenchimento Local (Offline): $_selectedCategory • $_selectedPaymentMethod • ${_formatSelectedDate(_selectedDate)}'
                                      : 'Revisão Inteligente: $_selectedCategory • $_selectedPaymentMethod • ${_formatSelectedDate(_selectedDate)}',
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

            // Abas Despesa / Receita / Boleto / Conta (T015)
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
                      isSelected:
                          !_isBillMode && _selectedType == TransactionType.expense,
                      selectedColor: AppTheme.navyDark,
                      onTap: () {
                        setState(() {
                          _isBillMode = false;
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
                      isSelected:
                          !_isBillMode && _selectedType == TransactionType.income,
                      selectedColor: AppTheme.emeraldPrimary,
                      onTap: () {
                        setState(() {
                          _isBillMode = false;
                          _selectedType = TransactionType.income;
                          _selectedCategory = 'Renda';
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _TypeTabButton(
                      key: const Key('tab_bill_button'),
                      label: 'Boleto / Conta',
                      isSelected: _isBillMode,
                      selectedColor: AppTheme.navyDark,
                      onTap: () {
                        setState(() {
                          _isBillMode = true;
                          _selectedType = TransactionType.expense;
                          if (_selectedCategory == 'Renda') {
                            _selectedCategory = 'Moradia';
                          }
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
                hintText: _isBillMode
                    ? 'Nome da conta/boleto (ex: Energia, Aluguel, Academia)'
                    : 'Nome da transação (ex: Supermercado, Aluguel)',
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

            // Categoria: Receita só pode ser 'Renda'; Despesa/Boleto nunca pode ser 'Renda'
            const Text(
              'Categoria',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!_isBillMode && _selectedType == TransactionType.income)
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

            if (!_isBillMode) ...[
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedPaymentMethod = method);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Seletor de Data / Data de Vencimento
            Text(
              _isBillMode ? 'Data de Vencimento' : 'Data',
              style: const TextStyle(
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

            if (_isBillMode) ...[
              const SizedBox(height: 16),

              // Linha Digitável / PIX Copia e Cola (Opcional) (T015)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Linha Digitável / PIX Copia e Cola (Opcional)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        key: const Key('manual_bill_paste_barcode_button'),
                        onPressed: isBusy ? null : _pasteBarcodeFromClipboard,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.content_paste_rounded, size: 14),
                        label: const Text(
                          'Colar',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_barcodeController.text.trim().isNotEmpty)
                        TextButton.icon(
                          key: const Key('manual_bill_copy_barcode_button'),
                          onPressed: isBusy ? null : _copyBarcodeToClipboard,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text(
                            'Copiar',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('manual_bill_barcode_field'),
                controller: _barcodeController,
                enabled: !isBusy,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'Cole aqui o código de barras ou PIX Copia e Cola...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
              ),
              const SizedBox(height: 14),

              // Switch Repetir mensalmente (Recorrente) (T015)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.subtleSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const Key('manual_bill_recurring_switch'),
                      value: _isRecurring,
                      thumbColor: _billSwitchThumbColor,
                      trackColor: _billSwitchTrackColor,
                      trackOutlineColor: _billSwitchOutlineColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      title: const Text(
                        'Repetir mensalmente (Recorrente)',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Ao dar baixa, agenda automaticamente o próximo mês.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      onChanged: isBusy
                          ? null
                          : (val) => setState(() => _isRecurring = val),
                    ),
                    const Divider(height: 1, color: AppTheme.cardBorder),
                    // Switch Desconta no Cartão (Incluso na Fatura) (T015 / FR-011b)
                    SwitchListTile(
                      key: const Key('manual_bill_credit_card_charge_switch'),
                      value: _isCreditCardCharge,
                      thumbColor: _billSwitchThumbColor,
                      trackColor: _billSwitchTrackColor,
                      trackOutlineColor: _billSwitchOutlineColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      title: const Text(
                        'Desconta no Cartão (Incluso na Fatura)',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Notifica 2x/dia e aloca na categoria, sem somar duplicado no total de boletos nem no saldo.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      onChanged: isBusy
                          ? null
                          : (val) => setState(() => _isCreditCardCharge = val),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),

            // Botão largo inferior verde "Confirmar e Salvar"
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('manual_save_button'),
                onPressed: isBusy ? null : _confirmAndSave,
                style: FilledButton.styleFrom(
                  backgroundColor: _isBillMode
                      ? AppTheme.navyDark
                      : AppTheme.emeraldPrimary,
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
                    : Text(
                        _isBillMode
                            ? 'Salvar Boleto / Conta'
                            : 'Confirmar e Salvar',
                        style: const TextStyle(
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
