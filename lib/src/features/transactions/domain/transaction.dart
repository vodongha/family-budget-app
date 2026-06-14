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

/// Who recorded a transaction (shown in the family view).
class TxnCreator {
  const TxnCreator({required this.rid, required this.displayName});

  final String rid;
  final String displayName;

  factory TxnCreator.fromJson(Map<String, dynamic> json) {
    return TxnCreator(
      rid: (json['rid'] ?? '') as String,
      displayName: (json['display_name'] ?? '') as String,
    );
  }
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
    this.createdBy,
    this.canEdit = true,
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

  /// Who recorded it (null only for legacy/unknown data).
  final TxnCreator? createdBy;

  /// Whether the current user may edit/delete it (true only for the creator).
  final bool canEdit;

  /// Signed amount for display (inflow +, outflow −).
  int get signedAmount => type.isInflow ? amount : -amount;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final dynamic cat = json['category'];
    final dynamic by = json['created_by'];
    return Transaction(
      rid: json['rid'] as String,
      walletRid: (json['wallet_rid'] ?? '') as String,
      type: TransactionType.fromApi((json['type'] ?? 'expense') as String),
      amount: (json['amount'] ?? 0) as int,
      occurredOn: DateTime.parse(json['occurred_on'] as String),
      note: json['note'] as String?,
      category:
          cat is Map ? Category.fromJson(cat.cast<String, dynamic>()) : null,
      createdBy:
          by is Map ? TxnCreator.fromJson(by.cast<String, dynamic>()) : null,
      canEdit: (json['can_edit'] ?? true) as bool,
    );
  }
}
