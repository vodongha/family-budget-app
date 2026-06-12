import '../../wallets/domain/wallet.dart';

/// Mirrors `GET /dashboard/summary`. All money fields are integer đồng.
class DashboardSummary {
  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.walletCount,
    required this.wallets,
  });

  final int totalIncome;
  final int totalExpense;
  final int netBalance;
  final int walletCount;
  final List<Wallet> wallets;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalIncome: (json['total_income'] ?? 0) as int,
      totalExpense: (json['total_expense'] ?? 0) as int,
      netBalance: (json['net_balance'] ?? 0) as int,
      walletCount: (json['wallet_count'] ?? 0) as int,
      wallets: ((json['wallets'] ?? []) as List)
          .map((e) => Wallet.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
