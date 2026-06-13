import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/dashboard_controller.dart';
import '../../stats/data/stats_repository.dart';
import '../../transactions/application/transactions_controller.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

/// Loads the family's wallets. Refreshable so other features (e.g. adding a
/// transaction) can invalidate it and force a reload of derived balances.
class WalletsController extends AsyncNotifier<List<Wallet>> {
  @override
  Future<List<Wallet>> build() {
    return ref.read(walletRepositoryProvider).list();
  }

  Future<void> create(String name, {String visibility = 'family'}) async {
    await ref
        .read(walletRepositoryProvider)
        .create(name, visibility: visibility);
    // A new personal wallet may change what the scoped dashboard shows.
    ref.invalidate(dashboardControllerProvider);
    ref.invalidateSelf();
    await future;
  }

  /// Delete a wallet (+ its transactions). Refreshes wallets and the other
  /// family-scoped views whose totals change. Returns the count removed.
  Future<int> delete(String rid) async {
    final int removed = await ref.read(walletRepositoryProvider).delete(rid);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(transactionsControllerProvider);
    ref.invalidate(monthlyStatsProvider);
    ref.invalidateSelf();
    await future;
    return removed;
  }
}

final walletsControllerProvider =
    AsyncNotifierProvider<WalletsController, List<Wallet>>(
        WalletsController.new);
