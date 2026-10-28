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
  final bool isFromOcr;
  final bool isOfflineFallback;
  final String? fallbackReason;

  /// Confiança abaixo de 50% exige alerta visual de revisão humana (Edge Case spec.md)
  bool get isLowConfidence => confidence < 0.50;

  factory AgentPredictionResponse.fromJson(Map<String, dynamic> json) {
    final normalizedDesc =
        (json['normalized_description'] ?? json['merchant'] ?? '') as String;
    final rawPayment =
        (json['payment_method'] ?? json['forma_pagamento']) as String?;
    return AgentPredictionResponse(
      category: json['category'] as String? ?? 'Outros',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription: normalizedDesc,
      estimatedAmount:
          ((json['estimated_amount'] ?? json['amount']) as num?)?.toDouble() ??
          0.0,
      budgetTip:
          json['budget_tip'] as String? ??
          'Revise os dados antes de confirmar o lançamento.',
      paymentMethod: rawPayment != null && rawPayment.trim().isNotEmpty
          ? rawPayment.trim()
          : InformalExpenseParser.inferPaymentMethod(normalizedDesc),
      inferredDate: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
    );
  }

  factory AgentPredictionResponse.fromOcrJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as String? ?? 'Comprovante OCR';
    final rawPayment =
        (json['payment_method'] ?? json['forma_pagamento']) as String?;
    return AgentPredictionResponse(
      category: json['category'] as String? ?? 'Outros',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription: merchant,
      estimatedAmount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      budgetTip:
          json['budget_tip'] as String? ??
          'Dados extraídos via leitura óptica de comprovante.',
      paymentMethod: rawPayment != null && rawPayment.trim().isNotEmpty
          ? rawPayment.trim()
          : InformalExpenseParser.inferPaymentMethod(merchant),
      inferredDate: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
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
    return AgentPredictionResponse(
      category: parsed.inferredCategory,
      confidence: 0.35,
      normalizedDescription: parsed.cleanDescription.isEmpty
          ? sanitized
          : parsed.cleanDescription,
      estimatedAmount: initialAmount ?? parsed.extractedAmount ?? 0.0,
      budgetTip:
          '$reason Você pode revisar e salvar manualmente no banco local (100% Offline-First).',
      paymentMethod: parsed.inferredPaymentMethod,
      inferredDate: parsed.inferredDate,
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
      isFromOcr: isFromOcr ?? this.isFromOcr,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
    );
  }
}

/// Extrator local auxiliar para entradas em linguagem natural (ex: "Almoço R$ 45 no débito")
class InformalExpenseParser {
  const InformalExpenseParser({
    required this.cleanDescription,
    required this.extractedAmount,
    required this.inferredCategory,
    this.inferredPaymentMethod = 'PIX',
    this.inferredDate,
  });

  final String cleanDescription;
  final double? extractedAmount;
  final String inferredCategory;
  final String inferredPaymentMethod;
  final DateTime? inferredDate;

  static String inferPaymentMethod(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('débito') || lower.contains('debito')) {
      return 'Débito';
    }
    if (lower.contains('crédito') ||
        lower.contains('credito') ||
        lower.contains('cartão') ||
        lower.contains('cartao') ||
        lower.contains('parcelado')) {
      return 'Crédito';
    }
    if (lower.contains('dinheiro') || lower.contains('espécie')) {
      return 'Dinheiro';
    }
    if (lower.contains('boleto') ||
        lower.contains('transferência') ||
        lower.contains('transferencia') ||
        lower.contains('ted')) {
      return 'Transferência';
    }
    if (lower.contains('pix')) {
      return 'PIX';
    }
    return 'PIX';
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

    final paymentMethod = inferPaymentMethod(trimmed);

    DateTime? inferredDate;
    final lower = trimmed.toLowerCase();
    final now = DateTime.now();
    if (lower.contains('ontem')) {
      inferredDate = now.subtract(const Duration(days: 1));
    } else if (lower.contains('anteontem')) {
      inferredDate = now.subtract(const Duration(days: 2));
    }

    final numberRegex = RegExp(r'(\d+(?:[.,]\d{1,2})?)');
    final matches = numberRegex.allMatches(trimmed).toList();
    double? amount;
    String description = trimmed;

    if (matches.isNotEmpty) {
      final lastMatch = matches.last;
      final rawNumber = lastMatch.group(1)!.replaceAll(',', '.');
      amount = double.tryParse(rawNumber);
      description = trimmed
          .replaceRange(lastMatch.start, lastMatch.end, '')
          .replaceAll(
            RegExp(
              r'\b(reais|real|r\$|no|na|em|via|debito|débito|crédito|credito|pix|dinheiro|cartão|cartao|ontem|hoje)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    if (description.isEmpty) {
      description = trimmed;
    } else {
      description =
          description[0].toUpperCase() + description.substring(1);
    }

    String category = 'Outros';
    if (lower.contains('uber') ||
        lower.contains('99') ||
        lower.contains('gasolina') ||
        lower.contains('posto') ||
        lower.contains('combustivel') ||
        lower.contains('combustível') ||
        lower.contains('transporte')) {
      category = 'Transporte';
    } else if (lower.contains('almoco') ||
        lower.contains('almoço') ||
        lower.contains('lanche') ||
        lower.contains('jantar') ||
        lower.contains('mercado') ||
        lower.contains('supermercado') ||
        lower.contains('ifood') ||
        lower.contains('habibs') ||
        lower.contains('padaria') ||
        lower.contains('cafe') ||
        lower.contains('café')) {
      category = 'Alimentação';
    } else if (lower.contains('aluguel') ||
        lower.contains('luz') ||
        lower.contains('agua') ||
        lower.contains('água') ||
        lower.contains('internet') ||
        lower.contains('condominio') ||
        lower.contains('condomínio')) {
      category = 'Moradia';
    } else if (lower.contains('farmacia') ||
        lower.contains('farmácia') ||
        lower.contains('medico') ||
        lower.contains('médico') ||
        lower.contains('exame')) {
      category = 'Saúde';
    } else if (lower.contains('cinema') ||
        lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('viagem')) {
      category = 'Lazer';
    } else if (lower.contains('curso') ||
        lower.contains('faculdade') ||
        lower.contains('escola') ||
        lower.contains('livro')) {
      category = 'Educação';
    } else if (lower.contains('investimento') ||
        lower.contains('tesouro') ||
        lower.contains('cdb') ||
        lower.contains('reserva')) {
      category = 'Investimentos';
    }

    return InformalExpenseParser(
      cleanDescription: description,
      extractedAmount: amount,
      inferredCategory: category,
      inferredPaymentMethod: paymentMethod,
      inferredDate: inferredDate,
    );
  }
}
