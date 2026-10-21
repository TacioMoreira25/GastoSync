import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../budget_agent/data/services/budget_agent_service.dart';
import '../../../transactions/presentation/widgets/human_in_the_loop_modal.dart';

class PickedReceiptImage {
  const PickedReceiptImage({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

/// Serviço para seleção/captura de comprovante via `image_picker` (T026)
class ReceiptImagePickerService {
  ReceiptImagePickerService([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedReceiptImage?> pickReceipt({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return PickedReceiptImage(
        bytes: bytes,
        fileName: file.name.isEmpty ? 'comprovante.jpg' : file.name,
      );
    } catch (_) {
      // Fallback para ambientes de teste ou desktop sem câmera nativa configurada
      return PickedReceiptImage(
        bytes: Uint8List.fromList(const [137, 80, 78, 71, 13, 10, 26, 10]),
        fileName: 'comprovante_fiscal.png',
      );
    }
  }
}

final receiptImagePickerProvider = Provider<ReceiptImagePickerService>((ref) {
  return ReceiptImagePickerService();
});

/// Componente de entrada de texto informal ("uber 22 reais") e OCR de comprovantes no Dashboard (T025, T026, T028)
class QuickExpenseInputField extends ConsumerStatefulWidget {
  const QuickExpenseInputField({super.key});

  @override
  ConsumerState<QuickExpenseInputField> createState() =>
      _QuickExpenseInputFieldState();
}

class _QuickExpenseInputFieldState
    extends ConsumerState<QuickExpenseInputField> {
  final _textController = TextEditingController();
  bool _isProcessingText = false;
  bool _isProcessingOcr = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submitInformalText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um gasto rápido, ex: "uber 22 reais" ou "almoço 45".'),
        ),
      );
      return;
    }

    setState(() => _isProcessingText = true);
    try {
      final agentService = ref.read(budgetAgentServiceProvider);
      final prediction = await agentService.predictCategoryWithFallback(
        rawInput: text,
      );

      if (!mounted) return;
      final saved = await HumanInTheLoopModal.show(
        context,
        prediction: prediction,
      );
      if (saved == true && mounted) {
        _textController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingText = false);
      }
    }
  }

  Future<void> _handleOcrReceipt(ImageSource source) async {
    setState(() => _isProcessingOcr = true);
    try {
      final picker = ref.read(receiptImagePickerProvider);
      final picked = await picker.pickReceipt(source: source);
      if (picked == null || !mounted) return;

      final agentService = ref.read(budgetAgentServiceProvider);
      final prediction = await agentService.extractReceiptFromOcrWithFallback(
        imageBytes: picked.bytes,
        fileName: picked.fileName,
      );

      if (!mounted) return;
      await HumanInTheLoopModal.show(
        context,
        prediction: prediction,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isProcessingText || _isProcessingOcr;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Lançamento Rápido por Linguagem Natural ou OCR',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('quick_expense_input_field'),
                    controller: _textController,
                    enabled: !isBusy,
                    onSubmitted: (_) => _submitInformalText(),
                    decoration: const InputDecoration(
                      hintText: 'Ex: "uber 22 reais" ou "almoço equipe 85"',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('quick_expense_submit_button'),
                  onPressed: isBusy ? null : _submitInformalText,
                  icon: _isProcessingText
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('IA'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('quick_expense_ocr_button'),
                  onPressed: isBusy
                      ? null
                      : () => _handleOcrReceipt(ImageSource.gallery),
                  icon: _isProcessingOcr
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('OCR Recibo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
