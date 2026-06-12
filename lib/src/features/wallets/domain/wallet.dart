/// A wallet (account/purse) within a family. Its [balance] is **derived** on
/// the backend (sum of signed transactions), never stored — the client just
/// displays whatever the API returns.
class Wallet {
  const Wallet({
    required this.rid,
    required this.name,
    required this.balance,
  });

  final String rid;
  final String name;

  /// Integer đồng.
  final int balance;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      rid: json['rid'] as String,
      name: json['name'] as String,
      balance: (json['balance'] ?? 0) as int,
    );
  }
}
