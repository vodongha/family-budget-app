import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallets/application/wallet_scope.dart';
import '../data/budget_repository.dart';
import '../domain/budget.dart';

/// Monthly category budgets (personal / family) with current-month spend.
/// Follows [walletScopeProvider].
class BudgetsController extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() {
    final WalletScope scope = ref.watch(walletScopeProvider);
    return ref.read(budgetRepositoryProvider).list(scope: scope.api);
  }

  Future<void> create(
      {required String categoryRid, required int amount}) async {
    final WalletScope scope = ref.read(walletScopeProvider);
    await ref.read(budgetRepositoryProvider).create(
          categoryRid: categoryRid,
          amount: amount,
          scope: scope.api,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit({required String rid, required int amount}) async {
    await ref.read(budgetRepositoryProvider).update(rid: rid, amount: amount);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String rid) async {
    await ref.read(budgetRepositoryProvider).delete(rid);
    ref.invalidateSelf();
    await future;
  }
}

final budgetsControllerProvider =
    AsyncNotifierProvider<BudgetsController, List<Budget>>(
  BudgetsController.new,
);
