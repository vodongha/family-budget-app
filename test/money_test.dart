import 'package:family_budget_app/src/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.parse', () {
    test('strips formatting and returns integer đồng', () {
      expect(Money.parse('50000'), 50000);
      expect(Money.parse('1.234.567'), 1234567);
      expect(Money.parse('  12 000 ₫ '), 12000);
    });

    test('returns null for empty / non-numeric input', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('₫'), isNull);
    });
  });

  group('Money.format', () {
    test('formats integer đồng with no decimals', () {
      // Grouping char is locale-dependent; assert on the digits + symbol.
      final String out = Money.format(1234567);
      expect(out.replaceAll(RegExp(r'[^0-9]'), ''), '1234567');
      expect(out.contains('₫'), isTrue);
      expect(out.contains(','), isFalse, reason: 'no decimal part for đồng');
    });
  });
}
