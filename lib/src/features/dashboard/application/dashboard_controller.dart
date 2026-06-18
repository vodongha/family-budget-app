import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs.dart';
import '../../wallets/application/wallet_scope.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

class DashboardController extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() {
    // Re-fetch whenever the family/personal scope toggle or display currency
    // changes.
    final WalletScope scope = ref.watch(walletScopeProvider);
    final String currency = ref.watch(displayCurrencyControllerProvider);
    return ref
        .read(dashboardRepositoryProvider)
        .summary(scope: scope.api, displayCurrency: currency);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSummary>(
        DashboardController.new);
