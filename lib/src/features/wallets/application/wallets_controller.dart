import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

/// Loads the family's wallets. Refreshable so other features (e.g. adding a
/// transaction) can invalidate it and force a reload of derived balances.
class WalletsController extends AsyncNotifier<List<Wallet>> {
  @override
  Future<List<Wallet>> build() {
    return ref.read(walletRepositoryProvider).list();
  }

  Future<void> create(String name) async {
    await ref.read(walletRepositoryProvider).create(name);
    ref.invalidateSelf();
    await future;
  }
}

final walletsControllerProvider =
    AsyncNotifierProvider<WalletsController, List<Wallet>>(
        WalletsController.new);
