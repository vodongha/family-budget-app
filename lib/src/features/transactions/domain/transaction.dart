import '../../categories/domain/category.dart';

/// Direction of a transaction. The amount itself is always a positive integer;
/// the type decides whether it adds to or subtracts from a wallet's balance.
/// `transferIn`/`transferOut` are the two legs of a wallet-to-wallet transfer.
enum TransactionType {
  expense,
  income,
  transferOut,
  transferIn;

  static TransactionType fromApi(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'transfer_in':
        return TransactionType.transferIn;
      case 'transfer_out':
        return TransactionType.transferOut;
      default:
        return TransactionType.expense;
    }
  }

  /// The backend value. expense/income round-trip; transfers are created via the
  /// transfer endpoint, so their api form uses snake_case for filtering.
  String get api => switch (this) {
        TransactionType.transferIn => 'transfer_in',
        TransactionType.transferOut => 'transfer_out',
        _ => name,
      };

  bool get isIncome => this == TransactionType.income;
  bool get isTransfer =>
      this == TransactionType.transferIn || this == TransactionType.transferOut;

  /// Whether this leg increases the wallet balance (income or transfer in).
  bool get isInflow =>
      this == TransactionType.income || this == TransactionType.transferIn;
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

  /// Signed amount for display (inflow +, outflow −).
  int get signedAmount => type.isInflow ? amount : -amount;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final dynamic cat = json['category'];
    return Transaction(
      rid: json['rid'] as String,
      walletRid: (json['wallet_rid'] ?? '') as String,
      type: TransactionType.fromApi((json['type'] ?? 'expense') as String),
      amount: (json['amount'] ?? 0) as int,
      occurredOn: DateTime.parse(json['occurred_on'] as String),
      note: json['note'] as String?,
      category:
          cat is Map ? Category.fromJson(cat.cast<String, dynamic>()) : null,
    );
  }
}
