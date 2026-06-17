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

  group('Money.parseIn (currency-aware)', () {
    test('0-decimal currency parses as whole minor units', () {
      expect(Money.parseIn('50000', 'VND'), 50000);
      expect(Money.parseIn('1.234.567', 'VND'), 1234567);
    });

    test('2-decimal currency converts a major amount to minor units', () {
      expect(Money.parseIn('10.50', 'USD'), 1050);
      expect(Money.parseIn('10', 'USD'), 1000);
      expect(Money.parseIn('0.5', 'USD'), 50);
      expect(Money.parseIn('10,5', 'EUR'), 1050); // comma as decimal sep
    });

    test('returns null for empty input', () {
      expect(Money.parseIn('', 'USD'), isNull);
    });
  });

  group('Money.formatIn', () {
    test('formats in the currency with its decimals and symbol', () {
      final String usd = Money.formatIn(1050, 'USD');
      expect(usd.replaceAll(RegExp(r'[^0-9]'), ''), '1050'); // 10.50
      expect(usd.contains(r'$'), isTrue);

      final String vnd = Money.formatIn(50000, 'VND');
      expect(vnd.replaceAll(RegExp(r'[^0-9]'), ''), '50000');
      expect(vnd.contains('₫'), isTrue);
    });

    test('editText round-trips through parseIn', () {
      expect(Money.parseIn(Money.editText(1050, 'USD'), 'USD'), 1050);
      expect(Money.parseIn(Money.editText(50000, 'VND'), 'VND'), 50000);
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
