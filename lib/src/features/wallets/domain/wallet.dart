/// A wallet (account/purse) within a family. Its [balance] is **derived** on
/// the backend (sum of signed transactions), never stored — the client just
/// displays whatever the API returns.
class Wallet {
  const Wallet({
    required this.rid,
    required this.name,
    required this.balance,
    this.visibility = 'family',
    this.txnCount = 0,
  });

  final String rid;
  final String name;

  /// `family` (shared with all members) or `personal` (private to its owner).
  final String visibility;

  /// Integer đồng.
  final int balance;

  /// Number of transactions in this wallet (shown before deleting).
  final int txnCount;

  /// A private wallet only its owner can see.
  bool get isPersonal => visibility == 'personal';

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      rid: json['rid'] as String,
      name: json['name'] as String,
      visibility: (json['visibility'] ?? 'family') as String,
      balance: (json['balance'] ?? 0) as int,
      txnCount: (json['txn_count'] ?? 0) as int,
    );
  }
}
