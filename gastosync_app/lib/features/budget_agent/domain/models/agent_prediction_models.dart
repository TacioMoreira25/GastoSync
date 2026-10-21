import 'package:freezed_annotation/freezed_annotation.dart';

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
      'description': description,
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
  final DateTime? inferredDate;
  final bool isFromOcr;
  final bool isOfflineFallback;
  final String? fallbackReason;

  /// Confiança abaixo de 50% exige alerta visual de revisão humana (Edge Case spec.md)
  bool get isLowConfidence => confidence < 0.50;

  factory AgentPredictionResponse.fromJson(Map<String, dynamic> json) {
    return AgentPredictionResponse(
      category: json['category'] as String? ?? 'Outros',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription:
          (json['normalized_description'] ?? json['merchant'] ?? '') as String,
      estimatedAmount:
          ((json['estimated_amount'] ?? json['amount']) as num?)?.toDouble() ??
          0.0,
      budgetTip:
          json['budget_tip'] as String? ??
          'Revise os dados antes de confirmar o lançamento.',
      inferredDate: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
    );
  }

  factory AgentPredictionResponse.fromOcrJson(Map<String, dynamic> json) {
    return AgentPredictionResponse(
      category: json['category'] as String? ?? 'Outros',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedDescription: json['merchant'] as String? ?? 'Comprovante OCR',
      estimatedAmount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      budgetTip:
          json['budget_tip'] as String? ??
          'Dados extraídos via leitura óptica de comprovante.',
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
    final parsed = InformalExpenseParser.parse(rawInput);
    return AgentPredictionResponse(
      category: parsed.inferredCategory,
      confidence: 0.35,
      normalizedDescription: parsed.cleanDescription.isEmpty
          ? rawInput.trim()
          : parsed.cleanDescription,
      estimatedAmount: initialAmount ?? parsed.extractedAmount ?? 0.0,
      budgetTip:
          '$reason Você pode revisar e salvar manualmente no banco local (100% Offline-First).',
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
      if (inferredDate != null) 'date': inferredDate!.toIso8601String(),
    };
  }

  AgentPredictionResponse copyWith({
    String? category,
    double? confidence,
    String? normalizedDescription,
    double? estimatedAmount,
    String? budgetTip,
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
      inferredDate: inferredDate ?? this.inferredDate,
      isFromOcr: isFromOcr ?? this.isFromOcr,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
    );
  }
}

/// Extrator local auxiliar para entradas em linguagem natural (ex: "uber 22 reais", "lanche tarde 25")
class InformalExpenseParser {
  const InformalExpenseParser({
    required this.cleanDescription,
    required this.extractedAmount,
    required this.inferredCategory,
  });

  final String cleanDescription;
  final double? extractedAmount;
  final String inferredCategory;

  static InformalExpenseParser parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const InformalExpenseParser(
        cleanDescription: '',
        extractedAmount: null,
        inferredCategory: 'Outros',
      );
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
            RegExp(r'\b(reais|real|r\$|no|debito|crédito|credito|pix)\b',
                caseSensitive: false),
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

    final lower = trimmed.toLowerCase();
    String category = 'Outros';
    if (lower.contains('uber') ||
        lower.contains('99') ||
        lower.contains('gasolina') ||
        lower.contains('posto') ||
        lower.contains('combustivel') ||
        lower.contains('transporte')) {
      category = 'Transporte';
    } else if (lower.contains('almoco') ||
        lower.contains('almoço') ||
        lower.contains('lanche') ||
        lower.contains('jantar') ||
        lower.contains('mercado') ||
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
        lower.contains('condominio')) {
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
    }

    return InformalExpenseParser(
      cleanDescription: description,
      extractedAmount: amount,
      inferredCategory: category,
    );
  }
}
