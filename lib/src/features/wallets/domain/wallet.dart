import 'package:flutter/material.dart';

/// A wallet (account/purse) within a family. Its [balance] is **derived** on
/// the backend (sum of signed transactions), never stored — the client just
/// displays whatever the API returns.
class Wallet {
  const Wallet({
    required this.rid,
    required this.name,
    required this.balance,
    this.visibility = 'family',
    this.icon,
    this.color,
    this.txnCount = 0,
  });

  final String rid;
  final String name;

  /// `family` (shared with all members) or `personal` (private to its owner).
  final String visibility;

  /// Optional emoji/icon (rendered as text), or null → a default icon.
  final String? icon;

  /// Optional hex colour (e.g. `#5B5BF0`), or null → a default colour.
  final String? color;

  /// Integer đồng.
  final int balance;

  /// Number of transactions in this wallet (shown before deleting).
  final int txnCount;

  /// A private wallet only its owner can see.
  bool get isPersonal => visibility == 'personal';

  /// Parsed [color] (accepts `#RRGGBB` or `RRGGBB`), falling back when unset.
  Color colorOr(Color fallback) {
    String? hex = color;
    if (hex == null || hex.isEmpty) {
      return fallback;
    }
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final int? value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      rid: json['rid'] as String,
      name: json['name'] as String,
      visibility: (json['visibility'] ?? 'family') as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      balance: (json['balance'] ?? 0) as int,
      txnCount: (json['txn_count'] ?? 0) as int,
    );
  }
}
