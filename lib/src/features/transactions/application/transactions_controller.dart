import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/dashboard_controller.dart';
import '../../wallets/application/wallets_controller.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

/// The recent transaction list. Adding a transaction invalidates this, the
/// wallets list, and the dashboard summary so derived balances stay consistent.
class TransactionsController extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() {
    return ref.read(transactionRepositoryProvider).list();
  }

  Future<void> add({
    required String walletRid,
    required TransactionType type,
    required int amount,
    String? note,
    String? categoryRid,
    DateTime? occurredOn,
  }) async {
    await ref.read(transactionRepositoryProvider).create(
          walletRid: walletRid,
          type: type,
          amount: amount,
          note: note,
          categoryRid: categoryRid,
          occurredOn: occurredOn,
        );
    // Balances are derived — invalidate everything that shows them.
    ref.invalidateSelf();
    ref.invalidate(walletsControllerProvider);
    ref.invalidate(dashboardControllerProvider);
    await future;
  }
}

final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, List<Transaction>>(
        TransactionsController.new);
