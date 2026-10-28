import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatador de entrada monetária no padrão Real Brasileiro (R$ 1.234,56).
/// Bloqueia letras/símbolos e formata automaticamente os centavos e separadores de milhar.
class BrlCurrencyInputFormatter extends TextInputFormatter {
  BrlCurrencyInputFormatter();

  static final NumberFormat _brlNumberFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  /// Formata um valor `double` para o padrão visual brasileiro (`1.234,56`).
  static String formatValue(double value) {
    if (value <= 0) return '';
    return _brlNumberFormat.format(value).trim();
  }

  /// Converte o texto formatado em Real (`1.234,56` ou `32,50`) para `double` (`1234.56`).
  static double parseValue(String? rawText) {
    if (rawText == null) return 0.0;
    final cleaned = rawText
        .replaceAll('R\$', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    if (cleaned.isEmpty) return 0.0;

    if (cleaned.contains(',')) {
      final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0.0;
    }

    return double.tryParse(cleaned) ?? 0.0;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Limita a 12 dígitos (até R$ 9.999.999.999,99) para evitar overflow
    final safeDigits = digitsOnly.length > 12
        ? digitsOnly.substring(0, 12)
        : digitsOnly;

    final cents = int.tryParse(safeDigits) ?? 0;
    if (cents == 0) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _brlNumberFormat.format(cents / 100.0).trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
