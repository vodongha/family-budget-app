import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Money helpers. Amounts are **integer đồng** end-to-end — the API sends and
/// receives whole-number minor units, and the UI only ever formats them. We
/// never parse money into a `double`; direction comes from the transaction
/// type, not the sign.
class Money {
  const Money._();

  static final NumberFormat _vnd = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Grouping only (no currency symbol), e.g. `1.234.567`. Used for input fields.
  static final NumberFormat _grouped = NumberFormat.decimalPattern('vi_VN');

  /// Formats integer đồng as `1.234.567 ₫`.
  static String format(int amount) => _vnd.format(amount);

  /// Formats integer đồng with thousands separators only: `1.234.567`.
  static String group(int amount) => _grouped.format(amount);

  /// Parses user input (digits, dots, spaces) into integer đồng.
  /// Returns null when the cleaned input is empty or not a whole number.
  static int? parse(String input) {
    final String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
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
