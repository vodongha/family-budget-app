import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Money helpers. Amounts are **integer đồng** end-to-end — the API sends and
/// receives whole-number minor units, and the UI only ever formats them. We
/// never parse money into a `double`; direction comes from the transaction
/// type, not the sign.
class Money {
  const Money._();

  static const String baseCurrency = 'VND';

  /// Supported ISO-4217 currencies → number of decimal places. Mirrors the
  /// backend's app/core/currency.py.
  static const Map<String, int> _decimals = {
    'VND': 0,
    'USD': 2,
    'EUR': 2,
    'JPY': 0,
    'GBP': 2,
    'AUD': 2,
    'SGD': 2,
    'KRW': 0,
    'CNY': 2,
    'THB': 2,
  };

  static const Map<String, String> _symbols = {
    'VND': '₫',
    'USD': r'$',
    'EUR': '€',
    'JPY': '¥',
    'GBP': '£',
    'AUD': r'A$',
    'SGD': r'S$',
    'KRW': '₩',
    'CNY': '¥',
    'THB': '฿',
  };

  static List<String> get supportedCurrencies => _decimals.keys.toList();

  static int decimalsFor(String currency) => _decimals[currency] ?? 0;

  static String symbolFor(String currency) => _symbols[currency] ?? currency;

  static int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static final NumberFormat _vnd = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Grouping only (no currency symbol), e.g. `1.234.567`. Used for input fields.
  static final NumberFormat _grouped = NumberFormat.decimalPattern('vi_VN');

  /// Formats base-currency (VND) integer minor units as `1.234.567 ₫`.
  static String format(int amount) => _vnd.format(amount);

  /// Formats integer **minor units of [currency]** with its symbol and decimals,
  /// e.g. `formatIn(1050, 'USD')` → `$10.50`, `formatIn(50000, 'VND')` → `50.000 ₫`.
  static String formatIn(int amountMinor, String currency) {
    final int dec = decimalsFor(currency);
    final NumberFormat f = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: symbolFor(currency),
      decimalDigits: dec,
    );
    return f.format(amountMinor / _pow10(dec));
  }

  /// Formats integer đồng with thousands separators only: `1.234.567`.
  static String group(int amount) => _grouped.format(amount);

  /// A plain, editable representation of [minorAmount] for an amount field:
  /// grouped digits for a 0-decimal currency (`1.234.567`), or a fixed-decimal
  /// major value for others (`10.50`). Used to pre-fill the field when editing.
  static String editText(int minorAmount, String currency) {
    final int dec = decimalsFor(currency);
    if (dec == 0) {
      return group(minorAmount);
    }
    return (minorAmount / _pow10(dec)).toStringAsFixed(dec);
  }

  /// The input formatters to use for an amount field in [currency]: live
  /// thousands grouping for a 0-decimal currency (VND/JPY/KRW), or free digits
  /// plus a decimal separator for currencies with minor units (USD/EUR/…).
  static List<TextInputFormatter> inputFormattersFor(String currency) {
    if (decimalsFor(currency) == 0) {
      return [ThousandsSeparatorInputFormatter()];
    }
    return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
  }

  /// Parses user input (digits, dots, spaces) into integer đồng.
  /// Returns null when the cleaned input is empty or not a whole number.
  static int? parse(String input) {
    final String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
  }

  /// Parses user input into integer **minor units of [currency]**. For a
  /// 0-decimal currency this is the whole number; for a 2-decimal one the user
  /// enters a major amount (e.g. `10.50`) which becomes `1050` minor units.
  /// The last `.`/`,` is treated as the decimal separator.
  static int? parseIn(String input, String currency) {
    final int dec = decimalsFor(currency);
    if (dec == 0) {
      return parse(input);
    }
    final String cleaned = input.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleaned.isEmpty) {
      return null;
    }
    // Normalise: the last separator is the decimal point; drop the rest.
    final int sep = cleaned.lastIndexOf(RegExp(r'[.,]'));
    final String intPart;
    final String fracPart;
    if (sep == -1) {
      intPart = cleaned.replaceAll(RegExp(r'[.,]'), '');
      fracPart = '';
    } else {
      intPart = cleaned.substring(0, sep).replaceAll(RegExp(r'[.,]'), '');
      fracPart = cleaned.substring(sep + 1).replaceAll(RegExp(r'[.,]'), '');
    }
    final String digits = (intPart.isEmpty ? '0' : intPart);
    final int? whole = int.tryParse(digits);
    if (whole == null) {
      return null;
    }
    final String frac = (fracPart + '0' * dec).substring(0, dec);
    final int fracVal = int.tryParse(frac.isEmpty ? '0' : frac) ?? 0;
    return whole * _pow10(dec) + fracVal;
  }
}

/// Live thousands-separator formatter for amount inputs: as the user types
/// digits, it regroups them as `1.234.567` (vi_VN grouping). [Money.parse]
/// strips the separators again on submit. The caret is kept at the end.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // While an IME composition is active (e.g. a Vietnamese keyboard on web),
    // rewriting the text desyncs the composing region and duplicates characters
    // (typing 50000 produced 550.000). Leave it alone until composing settles.
    if (newValue.composing.isValid) {
      return newValue;
    }
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final int? value = int.tryParse(digits);
    if (value == null) {
      // Too long to represent — keep the previous valid value.
      return oldValue;
    }
    final String formatted = Money.group(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
