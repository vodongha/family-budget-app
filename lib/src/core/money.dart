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

  /// Formats integer đồng as `1.234.567 ₫`.
  static String format(int amount) => _vnd.format(amount);

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
