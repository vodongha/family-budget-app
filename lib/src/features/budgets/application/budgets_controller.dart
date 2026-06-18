import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs.dart';
import '../../wallets/application/wallet_scope.dart';
import '../data/budget_repository.dart';
import '../domain/budget.dart';

/// Monthly category budgets (personal / family) with current-month spend.
/// Follows [walletScopeProvider] and the chosen display currency.
class BudgetsController extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() {
    final WalletScope scope = ref.watch(walletScopeProvider);
    final String currency = ref.watch(displayCurrencyControllerProvider);
    return ref
        .read(budgetRepositoryProvider)
        .list(scope: scope.api, displayCurrency: currency);
  }

  Future<void> create(
      {required String categoryRid, required int amount}) async {
    final WalletScope scope = ref.read(walletScopeProvider);
    final String currency = ref.read(displayCurrencyControllerProvider);
    await ref.read(budgetRepositoryProvider).create(
          categoryRid: categoryRid,
          amount: amount,
          scope: scope.api,
          displayCurrency: currency,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit({required String rid, required int amount}) async {
    final String currency = ref.read(displayCurrencyControllerProvider);
    await ref.read(budgetRepositoryProvider).update(
          rid: rid,
          amount: amount,
          displayCurrency: currency,
        );
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
