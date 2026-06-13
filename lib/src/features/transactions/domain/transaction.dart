import '../../categories/domain/category.dart';

/// Direction of a transaction. The amount itself is always a positive integer;
/// the type decides whether it adds to or subtracts from a wallet's balance.
enum TransactionType {
  expense,
  income;

  static TransactionType fromApi(String value) {
    return value == 'income' ? TransactionType.income : TransactionType.expense;
  }

  String get api => name; // 'expense' | 'income'
  bool get isIncome => this == TransactionType.income;
}

class Transaction {
  const Transaction({
    required this.rid,
    required this.walletRid,
    required this.type,
    required this.amount,
    required this.occurredOn,
    this.note,
    this.category,
  });

  final String rid;
  final String walletRid;
  final TransactionType type;

  /// Positive integer đồng.
  final int amount;
  final DateTime occurredOn;
  final String? note;

  /// The category this transaction is filed under, or null (uncategorized).
  final Category? category;

  /// Signed amount for display (income +, expense −).
  int get signedAmount => type.isIncome ? amount : -amount;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final dynamic cat = json['category'];
    return Transaction(
      rid: json['rid'] as String,
      walletRid: (json['wallet_rid'] ?? '') as String,
      type: TransactionType.fromApi((json['type'] ?? 'expense') as String),
      amount: (json['amount'] ?? 0) as int,
      occurredOn: DateTime.parse(json['occurred_on'] as String),
      note: json['note'] as String?,
      category: cat is Map
          ? Category.fromJson(cat.cast<String, dynamic>())
          : null,
    );
  }
}
