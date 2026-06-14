import 'package:family_budget_app/src/core/money.dart';
import 'package:flutter/services.dart';
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

  group('Money.group', () {
    test('groups thousands with dots (vi_VN), no symbol', () {
      expect(Money.group(50000), '50.000');
      expect(Money.group(44444444444), '44.444.444.444');
      expect(Money.group(0), '0');
    });
  });

  group('ThousandsSeparatorInputFormatter', () {
    TextEditingValue fmt(String text) => ThousandsSeparatorInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

    test('regroups digits and round-trips through Money.parse', () {
      expect(fmt('50000').text, '50.000');
      expect(fmt('44444444444').text, '44.444.444.444');
      expect(Money.parse(fmt('1234567').text), 1234567);
    });

    test('keeps the caret at the end and empties on no digits', () {
      final TextEditingValue v = fmt('1000');
      expect(v.selection.baseOffset, v.text.length);
      expect(fmt('').text, '');
      expect(fmt('abc').text, '');
    });

    test('leaves the value untouched while an IME is composing', () {
      // Reformatting mid-composition (e.g. Vietnamese keyboard on web) would
      // duplicate characters, so the value must pass through unchanged.
      const composing = TextEditingValue(
        text: '50000',
        composing: TextRange(start: 0, end: 5),
      );
      final out = ThousandsSeparatorInputFormatter()
          .formatEditUpdate(TextEditingValue.empty, composing);
      expect(out.text, '50000');
    });
  });
}
