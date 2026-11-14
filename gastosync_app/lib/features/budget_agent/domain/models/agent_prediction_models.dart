import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/security/owasp_prompt_sanitizer.dart';

/// Modelo imutável de requisição para categorização preditiva (Llama 3.3 via Groq)
@immutable
class AgentPredictionRequest {
  const AgentPredictionRequest({
    required this.description,
    this.amount,
    this.userId,
  });

  final String description;
  final double? amount;
  final String? userId;

  factory AgentPredictionRequest.fromJson(Map<String, dynamic> json) {
    return AgentPredictionRequest(
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble(),
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': OwaspPromptSanitizer.sanitize(description),
      if (amount != null) 'amount': amount,
      if (userId != null) 'user_id': userId,
    };
  }

  AgentPredictionRequest copyWith({
    String? description,
    double? amount,
    String? userId,
  }) {
    return AgentPredictionRequest(
      description: description ?? this.description,
      amount: amount ?? this.amount,
      userId: userId ?? this.userId,
    );
  }
}

/// Modelo imutável de resposta estruturada do Agente Preditivo (Categorização e OCR)
@immutable
class AgentPredictionResponse {
  const AgentPredictionResponse({
    required this.category,
    required this.confidence,
    required this.normalizedDescription,
    required this.estimatedAmount,
    required this.budgetTip,
    this.paymentMethod = 'PIX',
    this.inferredDate,
    this.inferredType = 'expense',
    this.isRecurring = false,
    this.isCreditCardCharge = false,
    this.isFromOcr = false,
    this.isOfflineFallback = false,
    this.fallbackReason,
  });

  final String category;
  final double confidence;
  final String normalizedDescription;
  final double estimatedAmount;
  final String budgetTip;
  final String paymentMethod;
  final DateTime? inferredDate;
  final String inferredType; // 'expense' | 'income' | 'bill'
  final bool isRecurring;
  final bool isCreditCardCharge;
  final bool isFromOcr;
  final bool isOfflineFallback;
  final String? fallbackReason;

  /// Confiança abaixo de 50% exige alerta visual de revisão humana (Edge Case spec.md)
  bool get isLowConfidence => confidence < 0.50;

  factory AgentPredictionResponse.fromJson(Map<String, dynamic> json) {
    final rawDesc =
        (json['normalized_description'] ?? json['merchant'] ?? '') as String;
    final normalizedDesc = InformalExpenseParser.cleanDescriptionText(rawDesc);
    final rawCategory = json['category'] as String? ?? 'Outros';
    final rawTxType =
        (json['tx_type'] ?? json['inferred_type'] ?? json['type']) as String?;
    final rawTip =
        json['budget_tip'] as String? ??
        'Revise os dados antes de confirmar o lançamento.';
    final rawPayment =
        (json['payment_method'] ?? json['forma_pagamento']) as String?;

    final inferredType = InformalExpenseParser.resolveTransactionType(
      explicitType: rawTxType,
      category: rawCategory,
      description: normalizedDesc,
      budgetTip: rawTip,
    );

    final effectiveCategory = inferredType == 'income'
        ? 'Renda'
        : (rawCategory == 'Outros' && normalizedDesc.isNotEmpty
              ? InformalExpenseParser.inferCategoryFromText(
                  normalizedDesc,
                  inferredType: inferredType,
                )
              : rawCategory);

    return AgentPredictionResponse(
      category: effectiveCategory,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription: normalizedDesc.isNotEmpty ? normalizedDesc : rawDesc,
      estimatedAmount:
          ((json['estimated_amount'] ?? json['amount']) as num?)?.toDouble() ??
          0.0,
      budgetTip: rawTip,
      paymentMethod: rawPayment != null && rawPayment.trim().isNotEmpty
          ? rawPayment.trim()
          : InformalExpenseParser.inferPaymentMethod(normalizedDesc),
      inferredDate: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      inferredType: inferredType,
      isRecurring:
          json['is_recurring'] == true ||
          InformalExpenseParser.inferIsRecurring(normalizedDesc),
      isCreditCardCharge:
          json['is_credit_card_charge'] == true ||
          InformalExpenseParser.inferIsCreditCardCharge(normalizedDesc),
    );
  }

  factory AgentPredictionResponse.fromOcrJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as String? ?? 'Comprovante OCR';
    final rawCategory = json['category'] as String? ?? 'Outros';
    final rawTxType =
        (json['tx_type'] ?? json['inferred_type'] ?? json['type']) as String?;
    final rawTip =
        json['budget_tip'] as String? ??
        'Dados extraídos via leitura óptica de comprovante.';
    final rawPayment =
        (json['payment_method'] ?? json['forma_pagamento']) as String?;

    final inferredType = InformalExpenseParser.resolveTransactionType(
      explicitType: rawTxType,
      category: rawCategory,
      description: merchant,
      budgetTip: rawTip,
    );

    return AgentPredictionResponse(
      category: inferredType == 'income' ? 'Renda' : rawCategory,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription: merchant,
      estimatedAmount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      budgetTip: rawTip,
      paymentMethod: rawPayment != null && rawPayment.trim().isNotEmpty
          ? rawPayment.trim()
          : InformalExpenseParser.inferPaymentMethod(merchant),
      inferredDate: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      inferredType: inferredType,
      isRecurring: json['is_recurring'] == true,
      isCreditCardCharge: json['is_credit_card_charge'] == true,
      isFromOcr: true,
    );
  }

  /// Construtor de fallback quando o backend está offline ou excede timeout
  factory AgentPredictionResponse.offlineFallback({
    required String rawInput,
    double? initialAmount,
    required String reason,
  }) {
    final sanitized = OwaspPromptSanitizer.sanitize(rawInput);
    final parsed = InformalExpenseParser.parse(sanitized);
    final defaultTip = InformalExpenseParser.defaultBudgetTipFor(
      inferredType: parsed.inferredType,
      category: parsed.inferredCategory,
    );
    return AgentPredictionResponse(
      category: parsed.inferredCategory,
      confidence: 0.35,
      normalizedDescription: parsed.cleanDescription.isEmpty
          ? sanitized
          : parsed.cleanDescription,
      estimatedAmount: initialAmount ?? parsed.extractedAmount ?? 0.0,
      budgetTip: '$defaultTip ($reason)',
      paymentMethod: parsed.inferredPaymentMethod,
      inferredDate: parsed.inferredDate,
      inferredType: parsed.inferredType,
      isRecurring: parsed.isRecurring,
      isCreditCardCharge: parsed.isCreditCardCharge,
      isOfflineFallback: true,
      fallbackReason: reason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'category': category,
      'confidence': confidence,
      'normalized_description': normalizedDescription,
      'estimated_amount': estimatedAmount,
      'budget_tip': budgetTip,
      'payment_method': paymentMethod,
      'tx_type': inferredType,
      'is_recurring': isRecurring,
      'is_credit_card_charge': isCreditCardCharge,
      if (inferredDate != null) 'date': inferredDate!.toIso8601String(),
    };
  }

  AgentPredictionResponse copyWith({
    String? category,
    double? confidence,
    String? normalizedDescription,
    double? estimatedAmount,
    String? budgetTip,
    String? paymentMethod,
    DateTime? inferredDate,
    String? inferredType,
    bool? isRecurring,
    bool? isCreditCardCharge,
    bool? isFromOcr,
    bool? isOfflineFallback,
    String? fallbackReason,
  }) {
    return AgentPredictionResponse(
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      normalizedDescription:
          normalizedDescription ?? this.normalizedDescription,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      budgetTip: budgetTip ?? this.budgetTip,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      inferredDate: inferredDate ?? this.inferredDate,
      inferredType: inferredType ?? this.inferredType,
      isRecurring: isRecurring ?? this.isRecurring,
      isCreditCardCharge: isCreditCardCharge ?? this.isCreditCardCharge,
      isFromOcr: isFromOcr ?? this.isFromOcr,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
    );
  }
}

/// Extrator local inteligente para entradas em linguagem natural
/// (ex: "Salario de 1500", "Almoço R$ 45,90 no débito", "Boleto luz 180 vence dia 20")
class InformalExpenseParser {
  const InformalExpenseParser({
    required this.cleanDescription,
    required this.extractedAmount,
    required this.inferredCategory,
    this.inferredPaymentMethod = 'PIX',
    this.inferredDate,
    this.inferredType = 'expense',
    this.isRecurring = false,
    this.isCreditCardCharge = false,
  });

  final String cleanDescription;
  final double? extractedAmount;
  final String inferredCategory;
  final String inferredPaymentMethod;
  final DateTime? inferredDate;
  final String inferredType; // 'expense' | 'income' | 'bill'
  final bool isRecurring;
  final bool isCreditCardCharge;

  static final RegExp _incomeRegex = RegExp(
    r'\b(sal[aá]rios?|rendas?|freelas?|freelances?|freelancers?|recebi(?:do|mento)?|b[oô]nus|13[ºo°]|d[eé]cimo\s+terceiro|pr[oó][\s-]?labore|dividendos?|rendimentos?|reembolsos?|comiss[aã]o|comiss[oõ]es|aposentadorias?|pens[aã]o|bolsas?|mesadas?|adiantamentos?|lucros?|honor[aá]rios?|cach[eê]s?|restitui[cç][aã]o|pr[eê]mios?|venda\s+de|pix\s+recebido|transfer[eê]ncia\s+recebida|dep[oó]sito\s+recebido|pagamento\s+recebido|aluguel\s+recebido|f[eé]rias\s+recebidas?)\b',
    caseSensitive: false,
  );

  static final RegExp _billRegex = RegExp(
    r'\b(boletos?|contas?\s+a\s+pagar|vence(?:\s+dia)?|vencimento|agendar\s+conta|fatura\s+do\s+cart[aã]o|fatura\s+cart[aã]o)\b',
    caseSensitive: false,
  );

  static final RegExp _paidRegex = RegExp(
    r'\b(paguei|pago|paga|quitei|quitado)\b',
    caseSensitive: false,
  );

  static final RegExp _recurringRegex = RegExp(
    r'\b(recorrente|mensal|mensalidade|todo\s+m[eê]s|assinatura|fix[ao])\b',
    caseSensitive: false,
  );

  static final RegExp _creditCardChargeRegex = RegExp(
    r'\b(no\s+cart[aã]o|na\s+fatura|cart[aã]o\s+de\s+cr[eé]dito|cobran[cç]a\s+no\s+cart[aã]o)\b',
    caseSensitive: false,
  );

  static bool isLikelyIncome(String text) {
    if (text.trim().isEmpty) return false;
    return _incomeRegex.hasMatch(text.toLowerCase());
  }

  static bool isLikelyBill(String text) {
    if (text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    if (isLikelyIncome(lower)) return false;
    if (_paidRegex.hasMatch(lower)) return false;
    return _billRegex.hasMatch(lower);
  }

  static bool inferIsRecurring(String text) {
    return _recurringRegex.hasMatch(text.toLowerCase());
  }

  static bool inferIsCreditCardCharge(String text) {
    return _creditCardChargeRegex.hasMatch(text.toLowerCase());
  }

  static String resolveTransactionType({
    String? explicitType,
    String? category,
    String? description,
    String? budgetTip,
  }) {
    final normType = explicitType?.trim().toLowerCase() ?? '';
    if (normType == 'income' || normType == 'receita' || normType == 'renda') {
      return 'income';
    }
    if (normType == 'bill' || normType == 'boleto' || normType == 'conta') {
      return 'bill';
    }
    final normCat = category?.trim().toLowerCase() ?? '';
    if (normCat == 'renda' || normCat.startsWith('renda ')) {
      return 'income';
    }
    final desc = description ?? '';
    if (isLikelyIncome(desc)) {
      return 'income';
    }
    if (isLikelyBill(desc)) {
      return 'bill';
    }
    final tip = budgetTip?.toLowerCase() ?? '';
    if (tip.contains('parte da renda') ||
        tip.contains('receita recebida') ||
        tip.contains('seu salário') ||
        tip.contains('seu salario')) {
      return 'income';
    }
    return 'expense';
  }

  static String inferPaymentMethod(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('débito') || lower.contains('debito')) {
      return 'Débito';
    }
    if (lower.contains('crédito') ||
        lower.contains('credito') ||
        lower.contains('cartão') ||
        lower.contains('cartao') ||
        lower.contains('parcelado') ||
        RegExp(r'\b\d+\s*x\b').hasMatch(lower)) {
      return 'Crédito';
    }
    if (lower.contains('dinheiro') ||
        lower.contains('espécie') ||
        lower.contains('especie')) {
      return 'Dinheiro';
    }
    if (lower.contains('boleto')) {
      return 'Boleto';
    }
    if (lower.contains('transferência') ||
        lower.contains('transferencia') ||
        lower.contains('ted') ||
        lower.contains('doc')) {
      return 'Transferência';
    }
    if (lower.contains('pix')) {
      return 'PIX';
    }
    return 'PIX';
  }

  static String inferCategoryFromText(
    String input, {
    String inferredType = 'expense',
  }) {
    final lower = input.toLowerCase();
    if (inferredType == 'income' || isLikelyIncome(lower)) {
      return 'Renda';
    }
    if (RegExp(
      r'\b(uber|99|99pop|t[aá]xi|gasolina|etanol|[aá]lcool|diesel|posto|ipiranga|shell|petrobras|combust[ií]vel|estacionamento|ped[aá]gio|sem\s*parar|veloe|metr[oô]|[oô]nibus|passagem|bilhete\s+[uú]nico|oficina|mec[aâ]nico|pneu|ipva|licenciamento|lavagem|lava\s*r[aá]pido|transporte)\b',
    ).hasMatch(lower)) {
      return 'Transporte';
    }
    if (RegExp(
      r'\b(almo[cç]o|lanche|jantar|caf[eé]|padaria|mercado|supermercado|atacad[aã]o|assa[ií]|carrefour|ifood|rappi|z[eé]\s*delivery|restaurante|pizzaria|pizza|hamb[uú]rguer|burger|mcdonalds|bk|habibs|habib|a[cç]ougue|hortifruti|feira|a[cç]a[ií]|sorvete|doceria|confeitaria|churrasco|marmita|quentinha|refei[cç][aã]o|alimenta[cç][aã]o|comida|sushi|pastel)\b',
    ).hasMatch(lower)) {
      return 'Alimentação';
    }
    if (RegExp(
      r'\b(aluguel|condom[ií]nio|luz|energia|enel|cpfl|cemig|coelba|celpe|copel|light|neoenergia|equatorial|[aá]gua|sabesp|copasa|sanepar|caesb|embasa|g[aá]s|comg[aá]s|botij[aã]o|internet|wi-?fi|fibra|vivo|claro|tim|oi|iptu|faxina|diarista|reforma|m[oó]veis|eletrodom[eé]stico|moradia)\b',
    ).hasMatch(lower)) {
      return 'Moradia';
    }
    if (RegExp(
      r'\b(farm[aá]cia|drogaria|droga\s*raia|drogasil|pague\s*menos|panvel|rem[eé]dio|medicamento|m[eé]dico|consulta|exame|laborat[oó]rio|dentista|odonto|psic[oó]logo|terapia|psiquiatra|hospital|cl[ií]nica|plano\s+de\s+sa[uú]de|unimed|amil|hapvida|academia|smart\s*fit|bluefit|suplemento|whey|creatina|[oó]culos|[oó]tica|sa[uú]de)\b',
    ).hasMatch(lower)) {
      return 'Saúde';
    }
    if (RegExp(
      r'\b(cinema|ingresso|show|teatro|netflix|spotify|disney|prime\s*video|amazon\s*prime|hbo|max|globoplay|youtube|apple\s*tv|crunchyroll|deezer|jogos?|game|steam|playstation|psn|xbox|nintendo|viagem|hotel|pousada|airbnb|hospedagem|passeio|parque|festa|balada|bar|cerveja|chopp|streaming|lazer)\b',
    ).hasMatch(lower)) {
      return 'Lazer';
    }
    if (RegExp(
      r'\b(curso|faculdade|universidade|escola|col[eé]gio|p[oó]s[\s-]?gradua[cç][aã]o|mba|livro|livraria|apostila|material\s+escolar|papelaria|udemy|alura|coursera|rocketseat|ingl[eê]s|idioma|matr[ií]cula|educa[cç][aã]o|estudo)\b',
    ).hasMatch(lower)) {
      return 'Educação';
    }
    if (RegExp(
      r'\b(investimentos?|tesouro|selic|cdb|lci|lca|fii|fundo\s+imobili[aá]rio|a[cç][oõ]es|bolsa\s+de\s+valores|cripto|bitcoin|btc|poupan[cç]a|reserva|aporte|previd[eê]ncia|cofrinho|caixinha)\b',
    ).hasMatch(lower)) {
      return 'Investimentos';
    }
    if (inferredType == 'bill') {
      return 'Moradia';
    }
    return 'Outros';
  }

  static String defaultBudgetTipFor({
    required String inferredType,
    required String category,
  }) {
    if (inferredType == 'income' || category == 'Renda') {
      return 'Receita identificada: reserve ao menos 20% para sua meta de poupança ou reserva de emergência.';
    }
    if (inferredType == 'bill') {
      return 'Conta/boleto identificado: mantenha o vencimento em dia para evitar juros e multas.';
    }
    switch (category) {
      case 'Alimentação':
        return 'Acompanhe seus gastos com refeições e mercado para manter o teto mensal de Alimentação.';
      case 'Moradia':
        return 'Despesas fixas de moradia devem idealmente ficar dentro de 30% da sua renda mensal.';
      case 'Transporte':
        return 'Monitore deslocamentos e combustível para otimizar seu orçamento de Transporte.';
      case 'Saúde':
        return 'Gastos com saúde e bem-estar são prioritários; mantenha seus comprovantes organizados.';
      case 'Lazer':
        return 'Equilibre lazer e assinaturas para preservar sua taxa de poupança mensal.';
      case 'Educação':
        return 'Investir em educação traz retorno no longo prazo; acompanhe dentro do seu planejamento.';
      case 'Investimentos':
        return 'Excelente hábito! Aportes constantes aceleram a construção da sua reserva financeira.';
      default:
        return 'Revise os dados preenchidos automaticamente antes de confirmar o lançamento.';
    }
  }

  static double? _parseBrlNumberString(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;

    // Caso 1: formato brasileiro com milhar e decimal "1.500,00" ou "12.345,67"
    if (cleaned.contains('.') && cleaned.contains(',')) {
      final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    // Caso 2: apenas ponto, mas no padrão de milhar brasileiro exato "1.500", "2.000", "10.500"
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(cleaned)) {
      return double.tryParse(cleaned.replaceAll('.', ''));
    }

    // Caso 3: vírgula decimal "45,90" ou "1500,5"
    if (cleaned.contains(',')) {
      return double.tryParse(cleaned.replaceAll(',', '.'));
    }

    // Caso 4: número simples ou decimal com ponto "1500" ou "45.90"
    return double.tryParse(cleaned);
  }

  static String cleanDescriptionText(String raw) {
    if (raw.trim().isEmpty) return '';
    var desc = raw.trim();

    // Remove expressões de pagamento e moedas residuais
    desc = desc.replaceAll(
      RegExp(
        r'\b(no\s+valor\s+de|valor\s+de|valor|reais|real|r\$|no\s+d[eé]bito|na\s+fatura|no\s+cr[eé]dito|no\s+cart[aã]o(?:\s+de\s+cr[eé]dito)?|via\s+pix|no\s+pix|pelo\s+pix|em\s+dinheiro|por\s+transfer[eê]ncia|no\s+boleto|d[eé]bito|cr[eé]dito|pix|dinheiro|transfer[eê]ncia|ontem|anteontem|hoje|amanh[aã])\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove preposições e conectores soltos no início ou no fim repetidamente
    final leadingConnector = RegExp(
      r'^(?:de|do|da|dos|das|no|na|nos|nas|em|por|pelo|pela|para|pro|pra|com|via|a|o|e|[-:,./])+[\s]+',
      caseSensitive: false,
    );
    final trailingConnector = RegExp(
      r'[\s]+(?:de|do|da|dos|das|no|na|nos|nas|em|por|pelo|pela|para|pro|pra|com|via|a|o|e|vence|vencimento|dia|[-:,./])+$',
      caseSensitive: false,
    );

    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    while (leadingConnector.hasMatch(desc)) {
      desc = desc.replaceFirst(leadingConnector, '').trim();
    }
    while (trailingConnector.hasMatch(desc)) {
      desc = desc.replaceFirst(trailingConnector, '').trim();
    }
    desc = desc.replaceAll(RegExp(r'^[-:,./\s]+|[-:,./\s]+$'), '').trim();

    if (desc.isEmpty) return '';

    // Normaliza acentuação comum em português quando digitado sem acento
    final wordReplacements = <RegExp, String>{
      RegExp(r'\bsalario\b', caseSensitive: false): 'Salário',
      RegExp(r'\balmoco\b', caseSensitive: false): 'Almoço',
      RegExp(r'\bcafe\b', caseSensitive: false): 'Café',
      RegExp(r'\bfarmacia\b', caseSensitive: false): 'Farmácia',
      RegExp(r'\bremedio\b', caseSensitive: false): 'Remédio',
      RegExp(r'\bmedico\b', caseSensitive: false): 'Médico',
      RegExp(r'\bcondominio\b', caseSensitive: false): 'Condomínio',
      RegExp(r'\bagua\b', caseSensitive: false): 'Água',
      RegExp(r'\bgas\b', caseSensitive: false): 'Gás',
      RegExp(r'\bcombustivel\b', caseSensitive: false): 'Combustível',
      RegExp(r'\bonibus\b', caseSensitive: false): 'Ônibus',
      RegExp(r'\bmetro\b', caseSensitive: false): 'Metrô',
      RegExp(r'\bbonus\b', caseSensitive: false): 'Bônus',
      RegExp(r'\bcomissao\b', caseSensitive: false): 'Comissão',
      RegExp(r'\bpensao\b', caseSensitive: false): 'Pensão',
      RegExp(r'\bdecimo\s+terceiro\b', caseSensitive: false): 'Décimo Terceiro',
    };

    for (final entry in wordReplacements.entries) {
      desc = desc.replaceAll(entry.key, entry.value);
    }

    return desc[0].toUpperCase() + desc.substring(1);
  }

  static InformalExpenseParser parse(String input) {
    final trimmed = OwaspPromptSanitizer.sanitize(input);
    if (trimmed.isEmpty) {
      return const InformalExpenseParser(
        cleanDescription: '',
        extractedAmount: null,
        inferredCategory: 'Outros',
      );
    }

    final lower = trimmed.toLowerCase();
    final now = DateTime.now();
    var workingText = trimmed;

    // 1. Extrai data primeiro e remove da string de trabalho para não confundir com o valor
    DateTime? inferredDate;

    final fullDateRegex = RegExp(
      r'\b(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?\b',
    );
    final dayOfMonthRegex = RegExp(
      r'\b(?:vence(?:mento)?\s*(?:no\s*|para\s*o\s*)?dia|vencimento\s+dia|para\s+o\s+dia|no\s+dia|dia)\s+(\d{1,2})\b',
      caseSensitive: false,
    );

    final fullDateMatch = fullDateRegex.firstMatch(workingText);
    if (fullDateMatch != null) {
      final day = int.tryParse(fullDateMatch.group(1)!);
      final month = int.tryParse(fullDateMatch.group(2)!);
      final rawYear = fullDateMatch.group(3);
      int year = now.year;
      if (rawYear != null) {
        final parsedYear = int.tryParse(rawYear) ?? now.year;
        year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
      }
      if (day != null &&
          month != null &&
          day >= 1 &&
          day <= 31 &&
          month >= 1 &&
          month <= 12) {
        inferredDate = DateTime(year, month, day);
        workingText = workingText.replaceRange(
          fullDateMatch.start,
          fullDateMatch.end,
          ' ',
        );
      }
    } else {
      final dayMatch = dayOfMonthRegex.firstMatch(workingText);
      if (dayMatch != null) {
        final day = int.tryParse(dayMatch.group(1)!);
        if (day != null && day >= 1 && day <= 31) {
          inferredDate = DateTime(now.year, now.month, day);
          workingText = workingText.replaceRange(
            dayMatch.start,
            dayMatch.end,
            ' ',
          );
        }
      } else if (lower.contains('anteontem')) {
        inferredDate = now.subtract(const Duration(days: 2));
      } else if (lower.contains('ontem')) {
        inferredDate = now.subtract(const Duration(days: 1));
      } else if (lower.contains('amanhã') || lower.contains('amanha')) {
        inferredDate = now.add(const Duration(days: 1));
      } else if (lower.contains('hoje')) {
        inferredDate = now;
      }
    }

    // 2. Extrai valor monetário (suportando "1,5 mil", "1.500,00", "1.500", "1500", "45,90")
    double? amount;

    // Protege "13º" / "13o" e parcelas "3x" para não serem confundidos com o valor
    var amountSearchText = workingText
        .replaceAll(RegExp(r'\b13[ºo°]\b', caseSensitive: false), '   ')
        .replaceAll(RegExp(r'\b\d+\s*x\b', caseSensitive: false), '   ');

    final milRegex = RegExp(
      r'(?:r\$\s*)?(\d+(?:[.,]\d+)?)\s*mil\b',
      caseSensitive: false,
    );
    final milMatch = milRegex.firstMatch(amountSearchText);
    if (milMatch != null) {
      final baseVal = double.tryParse(
        milMatch.group(1)!.replaceAll(',', '.'),
      );
      if (baseVal != null) {
        amount = baseVal * 1000.0;
        workingText = workingText.replaceRange(
          milMatch.start,
          milMatch.end,
          ' ',
        );
      }
    } else {
      final currencyNumberRegex = RegExp(
        r'(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final matches = currencyNumberRegex.allMatches(amountSearchText).toList();
      if (matches.isNotEmpty) {
        // Se houver mais de um número e o primeiro for "99" (do app 99), usa o último
        final chosenMatch = matches.last;
        final rawNumber = chosenMatch.group(1)!;
        amount = _parseBrlNumberString(rawNumber);
        workingText = workingText.replaceRange(
          chosenMatch.start,
          chosenMatch.end,
          ' ',
        );
      }
    }

    // 3. Infere tipo (Receita vs Boleto/Conta vs Despesa), recorrência e pagamento
    final inferredType = resolveTransactionType(description: trimmed);
    final isRecurring = inferIsRecurring(trimmed);
    final isCreditCardCharge = inferIsCreditCardCharge(trimmed);
    final paymentMethod = inferredType == 'bill' && !isCreditCardCharge
        ? 'Boleto'
        : inferPaymentMethod(trimmed);

    // 4. Infere categoria coerente com o tipo
    final category = inferCategoryFromText(
      trimmed,
      inferredType: inferredType,
    );

    // 5. Limpa e normaliza a descrição
    var description = cleanDescriptionText(workingText);
    if (description.isEmpty) {
      description = cleanDescriptionText(trimmed);
    }
    if (description.isEmpty) {
      description = trimmed;
    }

    return InformalExpenseParser(
      cleanDescription: description,
      extractedAmount: amount,
      inferredCategory: category,
      inferredPaymentMethod: paymentMethod,
      inferredDate: inferredDate,
      inferredType: inferredType,
      isRecurring: isRecurring,
      isCreditCardCharge: isCreditCardCharge,
    );
  }
}

/// Modelo imutável de telemetria pública e cota da IA (Groq Cloud no Render)
@immutable
class AgentQuotaStatus {
  const AgentQuotaStatus({
    required this.isOnline,
    required this.latencyMs,
    this.provider = 'Groq Cloud',
    required this.activeTextModel,
    this.fallbackTextModels = const <String>[],
    required this.activeOcrModel,
    this.fallbackOcrModels = const <String>[],
    required this.lastModelUsed,
    required this.totalRequests,
    this.dailyRequestLimit = 1000,
    required this.totalTokensUsed,
    this.minuteTokenLimit = 12000,
    required this.fallbackTriggers,
    this.checkedAt,
  });

  final bool isOnline;
  final int latencyMs;
  final String provider;
  final String activeTextModel;
  final List<String> fallbackTextModels;
  final String activeOcrModel;
  final List<String> fallbackOcrModels;
  final String lastModelUsed;
  final int totalRequests;
  final int dailyRequestLimit;
  final int totalTokensUsed;
  final int minuteTokenLimit;
  final int fallbackTriggers;
  final DateTime? checkedAt;

  factory AgentQuotaStatus.offline([int latencyMs = 0]) {
    return AgentQuotaStatus(
      isOnline: false,
      latencyMs: latencyMs,
      provider: 'Groq Cloud (Offline)',
      activeTextModel: 'Llama 3.3 (Fallback Local)',
      fallbackTextModels: const <String>[],
      activeOcrModel: 'OCR Offline (Fallback Local)',
      fallbackOcrModels: const <String>[],
      lastModelUsed: 'Motor Heurístico Local',
      totalRequests: 0,
      dailyRequestLimit: 1000,
      totalTokensUsed: 0,
      minuteTokenLimit: 12000,
      fallbackTriggers: 0,
      checkedAt: DateTime.now(),
    );
  }

  factory AgentQuotaStatus.fromJson(
    Map<String, dynamic> json, {
    int latencyMs = 0,
  }) {
    final status = (json['status'] as String? ?? 'ok').toLowerCase();
    final rawFallbackText = json['fallback_text_models'];
    final rawFallbackOcr = json['fallback_ocr_models'];

    return AgentQuotaStatus(
      isOnline: status == 'ok',
      latencyMs: latencyMs,
      provider: json['provider'] as String? ?? 'Groq Cloud',
      activeTextModel:
          json['active_text_model'] as String? ?? 'openai/gpt-oss-120b',
      fallbackTextModels: rawFallbackText is List
          ? rawFallbackText.map((e) => e.toString()).toList()
          : const <String>[],
      activeOcrModel:
          json['active_ocr_model'] as String? ?? 'llama-4-scout-17b',
      fallbackOcrModels: rawFallbackOcr is List
          ? rawFallbackOcr.map((e) => e.toString()).toList()
          : const <String>[],
      lastModelUsed: json['last_model_used'] as String? ?? '',
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      dailyRequestLimit: (json['daily_request_limit'] as num?)?.toInt() ?? 1000,
      totalTokensUsed: (json['total_tokens_used'] as num?)?.toInt() ?? 0,
      minuteTokenLimit: (json['minute_token_limit'] as num?)?.toInt() ?? 12000,
      fallbackTriggers: (json['fallback_triggers'] as num?)?.toInt() ?? 0,
      checkedAt: DateTime.now(),
    );
  }

  double get requestUsageRatio =>
      dailyRequestLimit > 0 ? (totalRequests / dailyRequestLimit).clamp(0.0, 1.0) : 0.0;

  double get requestUsagePercent => requestUsageRatio * 100.0;

  double get tokenUsageRatio =>
      minuteTokenLimit > 0 ? (totalTokensUsed / minuteTokenLimit).clamp(0.0, 1.0) : 0.0;

  double get tokenUsagePercent => tokenUsageRatio * 100.0;
}
