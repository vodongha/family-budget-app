import 'package:family_budget_app/src/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction', () {
    test('parses an expense and signs the amount negative', () {
      final Transaction t = Transaction.fromJson(const {
        'rid': '01HABC',
        'wallet_rid': '01WAL',
        'type': 'expense',
        'amount': 50000,
        'occurred_on': '2026-06-12',
        'note': 'Lunch',
      });

      expect(t.type, TransactionType.expense);
      expect(t.amount, 50000);
      expect(t.signedAmount, -50000);
      expect(t.note, 'Lunch');
      expect(t.occurredOn.year, 2026);
    });

    test('parses income and signs the amount positive', () {
      final Transaction t = Transaction.fromJson(const {
        'rid': '01HXYZ',
        'wallet_rid': '01WAL',
        'type': 'income',
        'amount': 200000,
        'occurred_on': '2026-06-01',
      });

      expect(t.type, TransactionType.income);
      expect(t.type.isIncome, isTrue);
      expect(t.signedAmount, 200000);
      expect(t.note, isNull);
    });

    test('unknown type defaults to expense', () {
      expect(TransactionType.fromApi('whatever'), TransactionType.expense);
    });
  });
}
