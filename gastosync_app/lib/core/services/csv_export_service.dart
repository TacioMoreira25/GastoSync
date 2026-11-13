import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../features/planning/domain/models/credit_card_model.dart';
import '../../features/transactions/domain/models/bill.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../theme/app_theme.dart';

/// Resultado estruturado da exportação CSV (T032 / US6).
@immutable
class CsvExportReport {
  const CsvExportReport({
    required this.fileName,
    required this.csvContent,
    required this.transactionsCsv,
    required this.billsCsv,
    required this.creditCardsCsv,
    required this.transactionsCount,
    required this.billsCount,
    required this.creditCardsCount,
    required this.generatedAt,
  });

  final String fileName;
  final String csvContent;
  final String transactionsCsv;
  final String billsCsv;
  final String creditCardsCsv;
  final int transactionsCount;
  final int billsCount;
  final int creditCardsCount;
  final DateTime generatedAt;

  int get totalRecordsCount =>
      transactionsCount + billsCount + creditCardsCount;

  /// Bytes UTF-8 do relatório consolidado (já incluindo UTF-8 BOM `\uFEFF` quando gerado com `includeBom: true`).
  Uint8List get utf8Bytes => Uint8List.fromList(utf8.encode(csvContent));
}

/// Serviço responsável por formatar registros de [Transaction], [Bill] e [CreditCard]
/// em padrão RFC-4180 com UTF-8 BOM (`\uFEFF`) para compatibilidade imediata com
/// Excel, Google Sheets e LibreOffice Calc (T032 / US6 / FR-017).
class CsvExportService {
  const CsvExportService._();

  /// Byte Order Mark (BOM) UTF-8 para reconhecimento automático de acentuação no Excel.
  static const String utf8Bom = '\uFEFF';

  /// Quebra de linha padrão RFC-4180 (`CRLF`).
  static const String crlf = '\r\n';

  /// Escapa um campo textual seguindo estritamente a RFC-4180 e previne CSV Formula Injection
  /// (campos iniciados por `=`, `+`, `-` ou `@` em textos não numéricos).
  static String escapeField(Object? rawValue, {bool sanitizeFormula = true}) {
    if (rawValue == null) return '';
    var text = rawValue.toString();
    if (text.isEmpty) return '';

    if (sanitizeFormula && _looksLikeFormulaInjection(text)) {
      text = "'$text";
    }

    final mustQuote = text.contains(',') ||
        text.contains('"') ||
        text.contains('\r') ||
        text.contains('\n') ||
        text.startsWith(' ') ||
        text.endsWith(' ');

    if (!mustQuote) {
      return text;
    }

    final escapedQuotes = text.replaceAll('"', '""');
    return '"$escapedQuotes"';
  }

  static bool _looksLikeFormulaInjection(String value) {
    if (value.isEmpty) return false;
    final first = value[0];
    if (first != '=' && first != '+' && first != '-' && first != '@') {
      return false;
    }
    // Permite números negativos legítimos (ex.: "-150.00")
    if (first == '-' && double.tryParse(value) != null) {
      return false;
    }
    return true;
  }

  /// Constrói uma linha RFC-4180 a partir de uma lista de campos.
  static String buildRow(Iterable<Object?> fields) {
    return fields.map(escapeField).join(',');
  }

  /// Formata a lista de transações ([Transaction]) em CSV RFC-4180.
  static String formatTransactionsCsv(
    Iterable<Transaction> transactions, {
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    bool includeBom = true,
  }) {
    final cardByUuid = <String, String>{
      for (final card in creditCards) card.clientUuid: card.name,
    };
    final dateFmt = DateFormat('yyyy-MM-dd');
    final activeTransactions =
        transactions.where((tx) => !tx.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    buffer.write(
      buildRow(const [
        'client_uuid',
        'data',
        'tipo',
        'categoria',
        'descricao',
        'forma_pagamento',
        'cartao_credito',
        'valor',
        'sincronizado',
      ]),
    );
    buffer.write(crlf);

    for (final tx in activeTransactions) {
      final cardName = tx.creditCardUuid != null
          ? (cardByUuid[tx.creditCardUuid!] ?? tx.creditCardUuid!)
          : '';
      buffer.write(
        buildRow([
          tx.clientUuid,
          dateFmt.format(tx.date),
          tx.type == TransactionType.income ? 'RECEITA' : 'DESPESA',
          tx.category,
          tx.description,
          tx.paymentMethod,
          cardName,
          tx.amount.toStringAsFixed(2),
          tx.isSynced ? 'SIM' : 'NAO',
        ]),
      );
      buffer.write(crlf);
    }

    return buffer.toString();
  }

  /// Formata a lista de boletos/contas ([Bill]) em CSV RFC-4180.
  static String formatBillsCsv(
    Iterable<Bill> bills, {
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    bool includeBom = true,
  }) {
    final cardByUuid = <String, String>{
      for (final card in creditCards) card.clientUuid: card.name,
    };
    final dateFmt = DateFormat('yyyy-MM-dd');
    final activeBills = bills.where((b) => !b.isDeleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    buffer.write(
      buildRow(const [
        'client_uuid',
        'vencimento',
        'status',
        'categoria',
        'descricao',
        'modalidade',
        'cartao_credito',
        'recorrente_mensal',
        'valor',
        'linha_digitavel_pix',
        'pago_em',
      ]),
    );
    buffer.write(crlf);

    for (final bill in activeBills) {
      final cardName = bill.creditCardUuid != null
          ? (cardByUuid[bill.creditCardUuid!] ?? bill.creditCardUuid!)
          : '';
      final statusLabel = bill.isPaid
          ? 'PAGO'
          : (bill.isOverdue() ? 'VENCIDO' : 'PENDENTE');
      buffer.write(
        buildRow([
          bill.clientUuid,
          dateFmt.format(bill.dueDate),
          statusLabel,
          bill.category,
          bill.description,
          bill.isCreditCardCharge ? 'FATURA_CARTAO' : 'BOLETO_CONTA',
          cardName,
          bill.isRecurring ? 'SIM' : 'NAO',
          bill.amount.toStringAsFixed(2),
          bill.barcode,
          bill.paidAt != null ? dateFmt.format(bill.paidAt!) : '',
        ]),
      );
      buffer.write(crlf);
    }

    return buffer.toString();
  }

  /// Formata o resumo de utilização e faixa saudável dos cartões ([CreditCard]) em CSV RFC-4180.
  static String formatCreditCardsCsv(
    Iterable<CreditCardUsageSummary> summaries, {
    bool includeBom = true,
  }) {
    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    buffer.write(
      buildRow(const [
        'client_uuid',
        'nome_cartao',
        'principal',
        'dia_vencimento',
        'limite_total',
        'assinaturas_fixas',
        'compras_variaveis',
        'total_utilizado',
        'percentual_utilizado',
        'faixa_saudavel_min_pct',
        'faixa_saudavel_max_pct',
        'teto_saudavel_reais',
        'margem_saudavel_restante',
        'alerta_acima_teto_saudavel',
      ]),
    );
    buffer.write(crlf);

    for (final summary in summaries) {
      final card = summary.card;
      buffer.write(
        buildRow([
          card.clientUuid,
          card.name,
          card.isPrimary ? 'SIM' : 'NAO',
          card.dueDay,
          card.limitAmount.toStringAsFixed(2),
          summary.fixedSubscriptionsAmount.toStringAsFixed(2),
          summary.variablePurchasesAmount.toStringAsFixed(2),
          summary.totalUsedAmount.toStringAsFixed(2),
          summary.utilizationPercent.toStringAsFixed(2),
          card.targetMinPercent.toStringAsFixed(0),
          card.targetMaxPercent.toStringAsFixed(0),
          card.healthyMaxAmount.toStringAsFixed(2),
          summary.remainingHealthyMargin.toStringAsFixed(2),
          summary.isAboveHealthyCeiling ? 'SIM' : 'NAO',
        ]),
      );
      buffer.write(crlf);
    }

    return buffer.toString();
  }

  /// Gera o relatório CSV consolidado RFC-4180 com UTF-8 BOM contendo:
  /// - `TRANSACAO` (receitas e despesas lançadas)
  /// - `BOLETO` (boletos e cobranças recorrentes na fatura)
  /// - `CARTAO_LIMITE` (cartões de crédito, divisão Fixas vs. Compras e faixa saudável 50%–80%)
  static CsvExportReport generateConsolidatedReport({
    required Iterable<Transaction> transactions,
    required Iterable<Bill> bills,
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    String? userEmail,
    DateTime? referenceDate,
    bool includeBom = true,
  }) {
    final now = referenceDate ?? DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final fileDateStamp = DateFormat('yyyyMMdd_HHmm').format(now);

    final activeTransactions =
        transactions.where((tx) => !tx.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final activeBills = bills.where((b) => !b.isDeleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final activeCards = creditCards.where((c) => !c.isDeleted).toList();

    final cardByUuid = <String, String>{
      for (final card in activeCards) card.clientUuid: card.name,
    };

    final cardSummaries = CreditCardUsageSummary.calculateAll(
      cards: activeCards,
      transactions: activeTransactions,
      bills: activeBills,
      referenceDate: now,
    );

    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    // Cabeçalho unificado RFC-4180
    buffer.write(
      buildRow(const [
        'secao_registro',
        'client_uuid',
        'data_referencia',
        'tipo_natureza',
        'status',
        'categoria',
        'descricao',
        'forma_pagamento',
        'cartao_credito',
        'valor',
        'limite_total_cartao',
        'faixa_saudavel_cartao',
        'margem_saudavel_restante',
        'recorrente_mensal',
        'linha_digitavel_pix',
        'sincronizado',
      ]),
    );
    buffer.write(crlf);

    // 1. Transações
    for (final tx in activeTransactions) {
      final cardName = tx.creditCardUuid != null
          ? (cardByUuid[tx.creditCardUuid!] ?? tx.creditCardUuid!)
          : '';
      buffer.write(
        buildRow([
          'TRANSACAO',
          tx.clientUuid,
          dateFmt.format(tx.date),
          tx.type == TransactionType.income ? 'RECEITA' : 'DESPESA',
          'EFETIVADO',
          tx.category,
          tx.description,
          tx.paymentMethod,
          cardName,
          tx.amount.toStringAsFixed(2),
          '',
          '',
          '',
          'NAO',
          '',
          tx.isSynced ? 'SIM' : 'NAO',
        ]),
      );
      buffer.write(crlf);
    }

    // 2. Boletos & Contas / Cobranças no Cartão
    for (final bill in activeBills) {
      final cardName = bill.creditCardUuid != null
          ? (cardByUuid[bill.creditCardUuid!] ?? bill.creditCardUuid!)
          : '';
      final statusLabel = bill.isPaid
          ? 'PAGO'
          : (bill.isOverdue(now) ? 'VENCIDO' : 'PENDENTE');
      buffer.write(
        buildRow([
          'BOLETO',
          bill.clientUuid,
          dateFmt.format(bill.dueDate),
          bill.isCreditCardCharge ? 'FATURA_CARTAO' : 'BOLETO_CONTA',
          statusLabel,
          bill.category,
          bill.description,
          bill.isCreditCardCharge ? 'Crédito' : 'Boleto',
          cardName,
          bill.amount.toStringAsFixed(2),
          '',
          '',
          '',
          bill.isRecurring ? 'SIM' : 'NAO',
          bill.barcode,
          bill.isSynced ? 'SIM' : 'NAO',
        ]),
      );
      buffer.write(crlf);
    }

    // 3. Resumo de Cartões & Limite Saudável (50%–80%)
    for (final summary in cardSummaries) {
      final card = summary.card;
      final dueDateThisMonth = DateTime(
        now.year,
        now.month,
        card.dueDay.clamp(1, 28),
      );
      final statusLabel = summary.isLimitExceeded
          ? 'LIMITE_EXCEDIDO'
          : (summary.isAboveHealthyCeiling
              ? 'ACIMA_TETO_SAUDAVEL'
              : (summary.isInHealthySweetSpot
                  ? 'FAIXA_IDEAL'
                  : 'USO_MODERADO'));

      buffer.write(
        buildRow([
          'CARTAO_LIMITE',
          card.clientUuid,
          dateFmt.format(dueDateThisMonth),
          card.isPrimary ? 'CARTAO_PRINCIPAL' : 'CARTAO_ADICIONAL',
          statusLabel,
          'Cartão de Crédito',
          '${card.name} (Fixas: R\$ ${summary.fixedSubscriptionsAmount.toStringAsFixed(2)} | Compras: R\$ ${summary.variablePurchasesAmount.toStringAsFixed(2)})',
          'Crédito',
          card.name,
          summary.totalUsedAmount.toStringAsFixed(2),
          card.limitAmount.toStringAsFixed(2),
          '${card.targetMinPercent.round()}%-${card.targetMaxPercent.round()}% (Teto R\$ ${card.healthyMaxAmount.toStringAsFixed(2)})',
          summary.remainingHealthyMargin.toStringAsFixed(2),
          'SIM',
          '',
          card.isSynced ? 'SIM' : 'NAO',
        ]),
      );
      buffer.write(crlf);
    }

    final sanitizedAccount = (userEmail ?? 'conta_local')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return CsvExportReport(
      fileName: 'gastosync_relatorio_${sanitizedAccount}_$fileDateStamp.csv',
      csvContent: buffer.toString(),
      transactionsCsv: formatTransactionsCsv(
        activeTransactions,
        creditCards: activeCards,
        includeBom: includeBom,
      ),
      billsCsv: formatBillsCsv(
        activeBills,
        creditCards: activeCards,
        includeBom: includeBom,
      ),
      creditCardsCsv: formatCreditCardsCsv(
        cardSummaries,
        includeBom: includeBom,
      ),
      transactionsCount: activeTransactions.length,
      billsCount: activeBills.length,
      creditCardsCount: cardSummaries.length,
      generatedAt: now,
    );
  }

  /// Exibe um modal interativo de exportação CSV (Consolidado, Transações, Boletos ou Cartões)
  /// com visualização prévia e cópia imediata para a área de transferência (T032 / T033).
  static Future<void> showExportModal(
    BuildContext context, {
    required Iterable<Transaction> transactions,
    required Iterable<Bill> bills,
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    String? userEmail,
  }) async {
    final report = generateConsolidatedReport(
      transactions: transactions,
      bills: bills,
      creditCards: creditCards,
      userEmail: userEmail,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CsvExportPreviewDialog(report: report),
    );
  }
}

class _CsvExportPreviewDialog extends StatefulWidget {
  const _CsvExportPreviewDialog({required this.report});

  final CsvExportReport report;

  @override
  State<_CsvExportPreviewDialog> createState() =>
      _CsvExportPreviewDialogState();
}

class _CsvExportPreviewDialogState extends State<_CsvExportPreviewDialog> {
  int _selectedSection = 0; // 0 = Consolidado, 1 = Transações, 2 = Boletos, 3 = Cartões

  String get _activeCsvContent {
    switch (_selectedSection) {
      case 1:
        return widget.report.transactionsCsv;
      case 2:
        return widget.report.billsCsv;
      case 3:
        return widget.report.creditCardsCsv;
      default:
        return widget.report.csvContent;
    }
  }

  String get _activeSectionLabel {
    switch (_selectedSection) {
      case 1:
        return 'Transações (${widget.report.transactionsCount})';
      case 2:
        return 'Boletos & Contas (${widget.report.billsCount})';
      case 3:
        return 'Cartões & Limite (${widget.report.creditCardsCount})';
      default:
        return 'Relatório Consolidado (${widget.report.totalRecordsCount})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _activeCsvContent.replaceFirst(
      CsvExportService.utf8Bom,
      '',
    );

    return AlertDialog(
      key: const Key('csv_export_preview_dialog'),
      backgroundColor: AppTheme.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emeraldSoftBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.table_view_rounded,
              color: AppTheme.emeraldDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exportar Relatório CSV',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.report.fileName,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTabChip(
                  index: 0,
                  label:
                      'Consolidado (${widget.report.totalRecordsCount})',
                  keyName: 'csv_tab_consolidated',
                ),
                _buildTabChip(
                  index: 1,
                  label:
                      'Transações (${widget.report.transactionsCount})',
                  keyName: 'csv_tab_transactions',
                ),
                _buildTabChip(
                  index: 2,
                  label: 'Boletos (${widget.report.billsCount})',
                  keyName: 'csv_tab_bills',
                ),
                _buildTabChip(
                  index: 3,
                  label: 'Cartões (${widget.report.creditCardsCount})',
                  keyName: 'csv_tab_cards',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  previewText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Formato RFC-4180 com UTF-8 BOM — compatível com Excel, Google Sheets e Numbers.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          key: const Key('csv_export_copy_button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.emeraldPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            await Clipboard.setData(ClipboardData(text: _activeCsvContent));
            navigator.pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  '$_activeSectionLabel copiado em CSV (RFC-4180) para a área de transferência!',
                ),
                backgroundColor: AppTheme.emeraldDeep,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.copy_all_rounded, size: 18),
          label: const Text('Copiar CSV'),
        ),
      ],
    );
  }

  Widget _buildTabChip({
    required int index,
    required String label,
    required String keyName,
  }) {
    final isSelected = _selectedSection == index;
    return ChoiceChip(
      key: Key(keyName),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedSection = index),
      selectedColor: AppTheme.emeraldSoftBg,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.emeraldDeep : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }
}
