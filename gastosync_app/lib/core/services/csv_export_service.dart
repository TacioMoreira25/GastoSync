import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/planning/domain/models/credit_card_model.dart';
import '../../features/transactions/domain/models/bill.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../theme/app_theme.dart';
import 'csv_downloader/csv_downloader.dart';

/// Linha estruturada para exibição limpa na pré-visualização do relatório CSV.
@immutable
class CsvPreviewRow {
  const CsvPreviewRow({
    required this.dateLabel,
    required this.typeLabel,
    required this.category,
    required this.description,
    required this.paymentOrDetail,
    required this.amountLabel,
    required this.statusLabel,
    this.isPositive = false,
  });

  final String dateLabel;
  final String typeLabel;
  final String category;
  final String description;
  final String paymentOrDetail;
  final String amountLabel;
  final String statusLabel;
  final bool isPositive;
}

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
    required this.totalIncome,
    required this.totalExpense,
    required this.pendingBillsTotal,
    required this.consolidatedRows,
    required this.transactionRows,
    required this.billRows,
    required this.cardRows,
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
  final double totalIncome;
  final double totalExpense;
  final double pendingBillsTotal;
  final List<CsvPreviewRow> consolidatedRows;
  final List<CsvPreviewRow> transactionRows;
  final List<CsvPreviewRow> billRows;
  final List<CsvPreviewRow> cardRows;
  final DateTime generatedAt;

  double get netBalance => totalIncome - totalExpense;

  int get totalRecordsCount =>
      transactionsCount + billsCount + creditCardsCount;

  /// Bytes UTF-8 do relatório consolidado (incluindo UTF-8 BOM `\uFEFF` quando gerado com `includeBom: true`).
  Uint8List get utf8Bytes => Uint8List.fromList(utf8.encode(csvContent));
}

/// Serviço responsável por formatar registros de [Transaction], [Bill] e [CreditCard]
/// em CSV estruturado e legível para planilhas.
class CsvExportService {
  const CsvExportService._();

  /// Byte Order Mark (BOM) UTF-8 para reconhecimento automático de acentuação em planilhas.
  static const String utf8Bom = '\uFEFF';

  /// Quebra de linha padrão (`CRLF`).
  static const String crlf = '\r\n';

  static DateTime _normalizeDate(DateTime date, {DateTime? fallback}) {
    if (date.year >= 2000) return date;
    if (fallback != null && fallback.year >= 2000) return fallback;
    return DateTime.now();
  }

  /// Escapa um campo textual e previne CSV Formula Injection
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
    if (first == '-' && double.tryParse(value) != null) {
      return false;
    }
    return true;
  }

  /// Constrói uma linha CSV a partir de uma lista de campos.
  static String buildRow(Iterable<Object?> fields) {
    return fields.map(escapeField).join(',');
  }

  /// Formata a lista de transações ([Transaction]) em CSV limpo e legível.
  static String formatTransactionsCsv(
    Iterable<Transaction> transactions, {
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    bool includeBom = true,
  }) {
    final cardByUuid = <String, String>{
      for (final card in creditCards) card.clientUuid: card.name,
    };
    final dateFmt = DateFormat('dd/MM/yyyy');
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final activeTransactions =
        transactions.where((tx) => !tx.isDeleted).toList()
          ..sort(
            (a, b) => _normalizeDate(b.date, fallback: b.updatedAt)
                .compareTo(_normalizeDate(a.date, fallback: a.updatedAt)),
          );

    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    buffer.write(
      buildRow(const [
        'Data',
        'Tipo',
        'Categoria',
        'Descrição',
        'Forma de Pagamento',
        'Cartão de Crédito',
        'Valor (R\$)',
        'Valor Numérico',
      ]),
    );
    buffer.write(crlf);

    for (final tx in activeTransactions) {
      final safeDate = _normalizeDate(tx.date, fallback: tx.updatedAt);
      final cardName = tx.creditCardUuid != null
          ? (cardByUuid[tx.creditCardUuid!] ?? '')
          : '';
      final signedAmount =
          tx.type == TransactionType.income ? tx.amount : -tx.amount;
      buffer.write(
        buildRow([
          dateFmt.format(safeDate),
          tx.type == TransactionType.income ? 'Receita' : 'Despesa',
          tx.category,
          tx.description,
          tx.paymentMethod,
          cardName,
          currencyFmt.format(tx.amount),
          signedAmount.toStringAsFixed(2),
        ]),
      );
      buffer.write(crlf);
    }

    return buffer.toString();
  }

  /// Formata a lista de boletos/contas ([Bill]) em CSV limpo e legível.
  static String formatBillsCsv(
    Iterable<Bill> bills, {
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    bool includeBom = true,
  }) {
    final cardByUuid = <String, String>{
      for (final card in creditCards) card.clientUuid: card.name,
    };
    final dateFmt = DateFormat('dd/MM/yyyy');
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final activeBills = bills.where((b) => !b.isDeleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    buffer.write(
      buildRow(const [
        'Vencimento',
        'Situação',
        'Categoria',
        'Descrição',
        'Modalidade',
        'Cartão de Crédito',
        'Recorrente Mensal',
        'Valor (R\$)',
        'Valor Numérico',
        'Pago em',
        'Linha Digitável / PIX',
      ]),
    );
    buffer.write(crlf);

    for (final bill in activeBills) {
      final safeDue = _normalizeDate(bill.dueDate, fallback: bill.updatedAt);
      final cardName = bill.creditCardUuid != null
          ? (cardByUuid[bill.creditCardUuid!] ?? '')
          : '';
      final statusLabel = bill.isPaid
          ? 'Pago'
          : (bill.isOverdue() ? 'Vencido' : 'Pendente');
      buffer.write(
        buildRow([
          dateFmt.format(safeDue),
          statusLabel,
          bill.category,
          bill.description,
          bill.isCreditCardCharge ? 'Cobrança no Cartão' : 'Boleto / Conta',
          cardName,
          bill.isRecurring ? 'Sim' : 'Não',
          currencyFmt.format(bill.amount),
          bill.amount.toStringAsFixed(2),
          bill.paidAt != null
              ? dateFmt.format(_normalizeDate(bill.paidAt!))
              : '',
          bill.barcode,
        ]),
      );
      buffer.write(crlf);
    }

    return buffer.toString();
  }

  /// Formata o resumo de utilização e faixa saudável dos cartões ([CreditCard]) em CSV limpo.
  static String formatCreditCardsCsv(
    Iterable<CreditCardUsageSummary> summaries, {
    bool includeBom = true,
  }) {
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    buffer.write(
      buildRow(const [
        'Cartão',
        'Principal',
        'Dia Vencimento',
        'Limite Total (R\$)',
        'Assinaturas Fixas (R\$)',
        'Compras Variáveis (R\$)',
        'Total Utilizado (R\$)',
        'Uso (%)',
        'Faixa Saudável',
        'Teto Saudável (R\$)',
        'Margem Saudável Restante (R\$)',
      ]),
    );
    buffer.write(crlf);

    for (final summary in summaries) {
      final card = summary.card;
      buffer.write(
        buildRow([
          card.name,
          card.isPrimary ? 'Sim' : 'Não',
          'Dia ${card.dueDay}',
          currencyFmt.format(card.limitAmount),
          currencyFmt.format(summary.fixedSubscriptionsAmount),
          currencyFmt.format(summary.variablePurchasesAmount),
          currencyFmt.format(summary.totalUsedAmount),
          '${summary.utilizationPercent.toStringAsFixed(1)}%',
          '${card.targetMinPercent.toStringAsFixed(0)}% a ${card.targetMaxPercent.toStringAsFixed(0)}%',
          currencyFmt.format(card.healthyMaxAmount),
          currencyFmt.format(summary.remainingHealthyMargin),
        ]),
      );
      buffer.write(crlf);
    }

    return buffer.toString();
  }

  /// Gera o relatório CSV consolidado contendo Resumo Financeiro, Transações, Boletos e Cartões.
  static CsvExportReport generateConsolidatedReport({
    required Iterable<Transaction> transactions,
    required Iterable<Bill> bills,
    Iterable<CreditCard> creditCards = const <CreditCard>[],
    String? userEmail,
    DateTime? referenceDate,
    bool includeBom = true,
  }) {
    final now = referenceDate ?? DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fileDateStamp = DateFormat('yyyyMMdd_HHmm').format(now);

    final activeTransactions =
        transactions.where((tx) => !tx.isDeleted).toList()
          ..sort(
            (a, b) => _normalizeDate(b.date, fallback: b.updatedAt)
                .compareTo(_normalizeDate(a.date, fallback: a.updatedAt)),
          );
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

    final totalIncome = activeTransactions
        .where((tx) => tx.isIncome)
        .fold<double>(0.0, (sum, tx) => sum + tx.amount);
    final totalExpense = activeTransactions
        .where((tx) => tx.isExpense)
        .fold<double>(0.0, (sum, tx) => sum + tx.amount);
    final pendingBillsTotal = activeBills
        .where((b) => !b.isPaid && !b.isCreditCardCharge)
        .fold<double>(0.0, (sum, b) => sum + b.amount);

    final consolidatedRows = <CsvPreviewRow>[];
    final transactionRows = <CsvPreviewRow>[];
    final billRows = <CsvPreviewRow>[];
    final cardRows = <CsvPreviewRow>[];

    final buffer = StringBuffer();
    if (includeBom) buffer.write(utf8Bom);

    // Cabeçalho limpo e organizado
    buffer.write(
      buildRow(const [
        'Data',
        'Seção',
        'Natureza',
        'Categoria',
        'Descrição',
        'Forma de Pagamento / Cartão',
        'Valor Formatado',
        'Valor Numérico',
        'Situação',
        'Observações',
      ]),
    );
    buffer.write(crlf);

    // 1. Transações
    for (final tx in activeTransactions) {
      final safeDate = _normalizeDate(tx.date, fallback: tx.updatedAt);
      final dateStr = dateFmt.format(safeDate);
      final isIncome = tx.type == TransactionType.income;
      final cardName = tx.creditCardUuid != null
          ? (cardByUuid[tx.creditCardUuid!] ?? '')
          : '';
      final paymentLabel = cardName.isNotEmpty
          ? '${tx.paymentMethod} ($cardName)'
          : tx.paymentMethod;
      final formattedVal =
          '${isIncome ? "+" : "-"} ${currencyFmt.format(tx.amount)}';

      buffer.write(
        buildRow([
          dateStr,
          'TRANSACAO',
          isIncome ? 'Receita' : 'Despesa',
          tx.category,
          tx.description,
          paymentLabel,
          formattedVal,
          tx.amount.toStringAsFixed(2),
          'Efetivado',
          '',
        ]),
      );
      buffer.write(crlf);

      final previewRow = CsvPreviewRow(
        dateLabel: dateStr,
        typeLabel: isIncome ? 'Receita' : 'Despesa',
        category: tx.category,
        description: tx.description,
        paymentOrDetail: paymentLabel,
        amountLabel: formattedVal,
        statusLabel: 'Efetivado',
        isPositive: isIncome,
      );
      consolidatedRows.add(previewRow);
      transactionRows.add(previewRow);
    }

    // 2. Boletos & Contas
    for (final bill in activeBills) {
      final safeDue = _normalizeDate(bill.dueDate, fallback: bill.updatedAt);
      final dateStr = dateFmt.format(safeDue);
      final cardName = bill.creditCardUuid != null
          ? (cardByUuid[bill.creditCardUuid!] ?? '')
          : '';
      final statusLabel = bill.isPaid
          ? 'Pago'
          : (bill.isOverdue(now) ? 'Vencido' : 'Pendente');
      final modalityLabel = bill.isCreditCardCharge
          ? (cardName.isNotEmpty ? 'Cartão ($cardName)' : 'Cobrança no Cartão')
          : 'Boleto / Conta';
      final formattedVal = currencyFmt.format(bill.amount);

      buffer.write(
        buildRow([
          dateStr,
          'BOLETO',
          modalityLabel,
          bill.category,
          bill.description,
          bill.isCreditCardCharge ? 'Crédito' : 'Boleto',
          formattedVal,
          bill.amount.toStringAsFixed(2),
          statusLabel,
          bill.isRecurring ? 'Recorrente mensal' : '',
        ]),
      );
      buffer.write(crlf);

      final previewRow = CsvPreviewRow(
        dateLabel: dateStr,
        typeLabel: 'Boleto / Conta',
        category: bill.category,
        description: bill.description,
        paymentOrDetail: modalityLabel,
        amountLabel: formattedVal,
        statusLabel: statusLabel,
      );
      consolidatedRows.add(previewRow);
      billRows.add(previewRow);
    }

    // 3. Cartões de Crédito & Limite Saudável
    for (final summary in cardSummaries) {
      final card = summary.card;
      final dueDateThisMonth = DateTime(
        now.year,
        now.month,
        card.dueDay.clamp(1, 28),
      );
      final dateStr = dateFmt.format(dueDateThisMonth);
      final statusLabel = summary.isLimitExceeded
          ? 'Limite Excedido'
          : (summary.isAboveHealthyCeiling
              ? 'Acima do Teto Saudável'
              : (summary.isInHealthySweetSpot
                  ? 'Faixa Ideal'
                  : 'Uso Moderado'));
      final detailLabel =
          'Limite: ${currencyFmt.format(card.limitAmount)} · Uso: ${summary.utilizationPercent.toStringAsFixed(1)}%';
      final formattedVal = currencyFmt.format(summary.totalUsedAmount);

      buffer.write(
        buildRow([
          dateStr,
          'CARTAO_LIMITE',
          card.isPrimary ? 'Cartão Principal' : 'Cartão Adicional',
          'Cartão de Crédito',
          card.name,
          detailLabel,
          formattedVal,
          summary.totalUsedAmount.toStringAsFixed(2),
          statusLabel,
          'Fixas: ${currencyFmt.format(summary.fixedSubscriptionsAmount)} | Compras: ${currencyFmt.format(summary.variablePurchasesAmount)}',
        ]),
      );
      buffer.write(crlf);

      final previewRow = CsvPreviewRow(
        dateLabel: 'Venc. dia ${card.dueDay}',
        typeLabel: card.isPrimary ? 'Cartão Principal' : 'Cartão',
        category: 'Cartão de Crédito',
        description: card.name,
        paymentOrDetail: detailLabel,
        amountLabel: formattedVal,
        statusLabel: statusLabel,
      );
      consolidatedRows.add(previewRow);
      cardRows.add(previewRow);
    }

    // 4. Linha final de Resumo Financeiro no CSV consolidado
    buffer.write(
      buildRow([
        dateFmt.format(now),
        'RESUMO',
        'Saldo Líquido',
        ' Geral',
        'Receitas: ${currencyFmt.format(totalIncome)} | Despesas: ${currencyFmt.format(totalExpense)}',
        'Boletos Pendentes: ${currencyFmt.format(pendingBillsTotal)}',
        currencyFmt.format(totalIncome - totalExpense),
        (totalIncome - totalExpense).toStringAsFixed(2),
        'Consolidado',
        '',
      ]),
    );
    buffer.write(crlf);

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
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      pendingBillsTotal: pendingBillsTotal,
      consolidatedRows: consolidatedRows,
      transactionRows: transactionRows,
      billRows: billRows,
      cardRows: cardRows,
      generatedAt: now,
    );
  }

  /// Exibe um modal interativo de exportação CSV (Consolidado, Transações, Boletos ou Cartões)
  /// com tabela visual organizada e botão direto para baixar o CSV.
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
  bool _isDownloading = false;

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

  List<CsvPreviewRow> get _activePreviewRows {
    switch (_selectedSection) {
      case 1:
        return widget.report.transactionRows;
      case 2:
        return widget.report.billRows;
      case 3:
        return widget.report.cardRows;
      default:
        return widget.report.consolidatedRows;
    }
  }

  String get _activeFileName {
    final base = widget.report.fileName;
    switch (_selectedSection) {
      case 1:
        return base.replaceFirst(
          'gastosync_relatorio_',
          'gastosync_transacoes_',
        );
      case 2:
        return base.replaceFirst('gastosync_relatorio_', 'gastosync_boletos_');
      case 3:
        return base.replaceFirst('gastosync_relatorio_', 'gastosync_cartoes_');
      default:
        return base;
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

  Future<void> _handleDownloadCsv() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final fileName = _activeFileName;
    final content = _activeCsvContent;

    try {
      final savedLocation = await downloadCsvFile(
        fileName: fileName,
        csvContent: content,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb || savedLocation == fileName
                ? 'Download do arquivo "$fileName" iniciado com sucesso!'
                : (savedLocation != null
                    ? 'CSV salvo com sucesso em: $savedLocation'
                    : '$_activeSectionLabel exportado com sucesso!'),
          ),
          backgroundColor: AppTheme.emeraldDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Não foi possível baixar o arquivo CSV: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final rows = _activePreviewRows;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return SafeArea(
      child: AlertDialog(
        key: const Key('csv_export_preview_dialog'),
        backgroundColor: AppTheme.cardSurface,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 40,
          vertical: 16,
        ),
      contentPadding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 12, isMobile ? 16 : 24, 8),
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
                  _activeFileName,
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
        width: isMobile ? double.maxFinite : 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Abas de seleção do relatório
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

              // Resumo rápido de Receitas, Despesas e Saldo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.subtleSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricMini(
                        label: 'Receitas',
                        value: currencyFmt.format(widget.report.totalIncome),
                        valueColor: AppTheme.emeraldDeep,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricMini(
                        label: 'Despesas',
                        value: currencyFmt.format(widget.report.totalExpense),
                        valueColor: AppTheme.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricMini(
                        label: 'Saldo Líquido',
                        value: currencyFmt.format(widget.report.netBalance),
                        valueColor: widget.report.netBalance >= 0
                            ? AppTheme.emeraldDeep
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tabela estruturada dos registros que serão exportados
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 28,
                        ),
                        child: Center(
                          child: Text(
                            'Nenhum registro nesta seção para exportar.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMobile) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: AppTheme.subtleSurface,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(11),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'DATA',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'DESCRIÇÃO / CATEGORIA',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'PAGAMENTO',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'VALOR',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppTheme.cardBorder),
                          ],
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: rows.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: AppTheme.cardBorder,
                              ),
                              itemBuilder: (context, index) {
                                final item = rows[index];
                                if (isMobile) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.description,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.dateLabel} · ${item.category}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                              Text(
                                                item.paymentOrDetail,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color:
                                                      AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              item.amountLabel,
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: item.isPositive
                                                    ? AppTheme.emeraldDeep
                                                    : AppTheme.textPrimary,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.dateLabel,
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.description,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${item.typeLabel} · ${item.category}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.paymentOrDetail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.amountLabel,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: item.isPositive
                                                ? AppTheme.emeraldDeep
                                                : AppTheme.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          key: const Key('csv_export_download_button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.emeraldPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isDownloading ? null : _handleDownloadCsv,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isDownloading ? 'Baixando...' : 'Baixar CSV'),
        ),
      ],
      ),
    );
  }

  Widget _buildMetricMini({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
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
