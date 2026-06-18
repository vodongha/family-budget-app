import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Money helpers. Amounts are **integer đồng** end-to-end — the API sends and
/// receives whole-number minor units, and the UI only ever formats them. We
/// never parse money into a `double`; direction comes from the transaction
/// type, not the sign.
class Money {
  const Money._();

  static const String baseCurrency = 'VND';

  /// Supported ISO-4217 currencies → number of decimal places. **Mirrors the
  /// backend's app/core/currency.py exactly** — keep the two in sync.
  static const Map<String, int> _decimals = {
    // Zero-decimal.
    'VND': 0,
    'JPY': 0,
    'KRW': 0,
    'CLP': 0,
    'ISK': 0,
    // Three-decimal.
    'KWD': 3,
    'BHD': 3,
    'OMR': 3,
    'JOD': 3,
    // Two-decimal.
    'USD': 2,
    'EUR': 2,
    'GBP': 2,
    'AUD': 2,
    'CAD': 2,
    'CHF': 2,
    'CNY': 2,
    'HKD': 2,
    'NZD': 2,
    'SGD': 2,
    'TWD': 2,
    'SEK': 2,
    'NOK': 2,
    'DKK': 2,
    'PLN': 2,
    'CZK': 2,
    'HUF': 2,
    'RON': 2,
    'BGN': 2,
    'TRY': 2,
    'RUB': 2,
    'UAH': 2,
    'THB': 2,
    'IDR': 2,
    'MYR': 2,
    'PHP': 2,
    'INR': 2,
    'PKR': 2,
    'BDT': 2,
    'LKR': 2,
    'AED': 2,
    'SAR': 2,
    'QAR': 2,
    'ILS': 2,
    'EGP': 2,
    'ZAR': 2,
    'NGN': 2,
    'KES': 2,
    'MAD': 2,
    'MXN': 2,
    'BRL': 2,
    'ARS': 2,
    'COP': 2,
    'PEN': 2,
  };

  /// Well-known symbols; currencies without one fall back to their code
  /// (see [symbolFor]).
  static const Map<String, String> _symbols = {
    'VND': '₫',
    'USD': r'$',
    'EUR': '€',
    'JPY': '¥',
    'GBP': '£',
    'AUD': r'A$',
    'CAD': r'C$',
    'CHF': 'Fr',
    'CNY': '¥',
    'HKD': r'HK$',
    'NZD': r'NZ$',
    'SGD': r'S$',
    'TWD': r'NT$',
    'KRW': '₩',
    'THB': '฿',
    'INR': '₹',
    'RUB': '₽',
    'TRY': '₺',
    'UAH': '₴',
    'PLN': 'zł',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'CZK': 'Kč',
    'HUF': 'Ft',
    'ILS': '₪',
    'PHP': '₱',
    'IDR': 'Rp',
    'MYR': 'RM',
    'ZAR': 'R',
    'NGN': '₦',
    'BRL': r'R$',
    'MXN': r'$',
    'AED': 'د.إ',
    'SAR': '﷼',
  };

  /// A few widely-used currencies surfaced first in pickers; the rest follow
  /// alphabetically.
  static const List<String> _popularOrder = [
    'VND', 'USD', 'EUR', 'JPY', 'GBP', 'CNY', 'KRW', 'AUD', //
    'CAD', 'CHF', 'SGD', 'HKD', 'THB', 'TWD',
  ];

  /// Supported currencies, popular ones first, then the rest A–Z.
  static List<String> get supportedCurrencies {
    final List<String> all = _decimals.keys.toList();
    final List<String> rest =
        all.where((c) => !_popularOrder.contains(c)).toList()..sort();
    return [
      ..._popularOrder.where(all.contains),
      ...rest,
    ];
  }

  static int decimalsFor(String currency) => _decimals[currency] ?? 0;

  static String symbolFor(String currency) => _symbols[currency] ?? currency;

  /// A picker label for a currency: `"USD  $"`, or just the code when there's
  /// no distinct symbol (`"CAD  C$"`, `"PEN"`).
  static String currencyLabel(String currency) {
    final String s = symbolFor(currency);
    return s == currency ? currency : '$currency  $s';
  }

  /// An example amount for a field hint, grouped and with the right number of
  /// decimals for [currency] (no symbol): `50.000` for VND, `50.000,00` for USD.
  static String hintExample(String currency) {
    final int dec = decimalsFor(currency);
    final NumberFormat f = NumberFormat.decimalPattern('vi_VN')
      ..minimumFractionDigits = dec
      ..maximumFractionDigits = dec;
    return f.format(50000);
  }

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
