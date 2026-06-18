import '../../wallets/domain/wallet.dart';

/// Mirrors `GET /dashboard/summary`. Totals are integer minor units of
/// [currency]; per-wallet balances stay in each wallet's own currency.
class DashboardSummary {
  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.currency,
    required this.walletCount,
    required this.wallets,
  });

  final int totalIncome;
  final int totalExpense;
  final int netBalance;

  /// The currency the totals above are expressed in (the chosen display currency).
  final String currency;
  final int walletCount;
  final List<Wallet> wallets;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalIncome: (json['total_income'] ?? 0) as int,
      totalExpense: (json['total_expense'] ?? 0) as int,
      netBalance: (json['net_balance'] ?? 0) as int,
      currency: (json['currency'] ?? 'VND') as String,
      walletCount: (json['wallet_count'] ?? 0) as int,
      wallets: ((json['wallets'] ?? []) as List)
          .map((e) => Wallet.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
