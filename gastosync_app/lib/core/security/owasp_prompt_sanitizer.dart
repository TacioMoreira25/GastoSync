/// Sanitizador de entradas no cliente Flutter (Conformidade OWASP MASVS).
/// Neutraliza tentativas de Prompt Injection, comandos de sobrescrita de sistema,
/// scripts e caracteres de controle antes do envio à API / LLM (Llama 3.3 70B).
class OwaspPromptSanitizer {
  OwaspPromptSanitizer._();

  static const int maxSafeInputLength = 240;

  static final List<RegExp> _injectionPatterns = [
    RegExp(
      r'ignore\s+(all\s+|previous\s+|prior\s+|above\s+)?(instructions|prompts|rules)',
      caseSensitive: false,
    ),
    RegExp(
      r'ignore\s+(todas\s+as\s+|as\s+)?(instru[cç][oõ]es|regras|ordens)(\s+anteriores)?',
      caseSensitive: false,
    ),
    RegExp(
      r'esque[cç]a\s+(tudo|as\s+instru[cç][oõ]es|o\s+contexto)',
      caseSensitive: false,
    ),
    RegExp(
      r'(system\s*prompt|system\s*override|developer\s*mode|jailbreak|dan\s*mode)',
      caseSensitive: false,
    ),
    RegExp(
      r'(<\|im_start\|>|<\|im_end\|>|<\|system\|>|<\|user\|>|<\|assistant\|>|\[INST\]|\[\/INST\])',
      caseSensitive: false,
    ),
    RegExp(
      r'(drop\s+table|delete\s+from|union\s+select|insert\s+into|--\s*$)',
      caseSensitive: false,
    ),
    RegExp(
      r'(<\s*script[^>]*>|javascript\s*:|onerror\s*=|onload\s*=)',
      caseSensitive: false,
    ),
  ];

  /// Verifica se o texto contém padrões suspeitos de Prompt Injection ou XSS/SQLi.
  static bool containsInjectionAttempt(String rawInput) {
    final normalized = rawInput.trim();
    if (normalized.isEmpty) return false;
    for (final pattern in _injectionPatterns) {
      if (pattern.hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  /// Sanitiza o texto removendo caracteres de controle, delimitadores de código/prompt
  /// e padrões de Prompt Injection antes de trafegar pela camada de rede (Dio).
  static String sanitize(String rawInput) {
    var cleaned = rawInput
        // Remove caracteres de controle ASCII não imprimíveis
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        // Remove blocos markdown/delimitadores que tentam fechar o prompt do sistema
        .replaceAll('```', ' ')
        .replaceAll('"""', ' ')
        .replaceAll("'''", ' ');

    for (final pattern in _injectionPatterns) {
      cleaned = cleaned.replaceAll(pattern, '[filtrado]');
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length > maxSafeInputLength) {
      cleaned = cleaned.substring(0, maxSafeInputLength).trim();
    }

    return cleaned;
  }
}
