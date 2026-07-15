import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/calendar_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../stats/data/stats_repository.dart';
import '../../wallets/application/wallet_scope.dart';
import '../../wallets/application/wallets_controller.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

/// Active filters for the transaction list. `null` fields mean "no filter".
typedef TxnFilter = ({
  TransactionType? type,
  String? categoryRid,
  String? walletRid,
  DateTime? from,
  DateTime? to,
});

const TxnFilter emptyTxnFilter =
    (type: null, categoryRid: null, walletRid: null, from: null, to: null);

final txnFilterProvider =
    NotifierProvider<TxnFilterNotifier, TxnFilter>(TxnFilterNotifier.new);

class TxnFilterNotifier extends Notifier<TxnFilter> {
  @override
  TxnFilter build() => emptyTxnFilter;

  void set(TxnFilter filter) => state = filter;
}

/// The recent transaction list. Mutations invalidate the wallets list, the
/// dashboard summary and the statistics so derived balances stay consistent.
class TransactionsController extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() {
    final WalletScope scope = ref.watch(walletScopeProvider);
    final TxnFilter f = ref.watch(txnFilterProvider);
    return ref.read(transactionRepositoryProvider).list(
          scope: scope.api,
          walletRid: f.walletRid,
          type: f.type,
          categoryRid: f.categoryRid,
          dateFrom: f.from,
          dateTo: f.to,
        );
  }

  void _invalidateDerived() {
    ref.invalidateSelf();
    ref.invalidate(walletsControllerProvider);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(monthlyStatsProvider);
    ref.invalidate(categoryStatsProvider);
    ref.invalidate(monthTransactionsProvider);
    ref.invalidate(calendarStatsProvider);
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
    _invalidateDerived();
    await future;
  }

  Future<void> edit({
    required String rid,
    required String walletRid,
    required TransactionType type,
    required int amount,
    String? note,
    String? categoryRid,
    DateTime? occurredOn,
  }) async {
    await ref.read(transactionRepositoryProvider).update(
          rid: rid,
          walletRid: walletRid,
          type: type,
          amount: amount,
          note: note,
          categoryRid: categoryRid,
          occurredOn: occurredOn,
        );
    _invalidateDerived();
    await future;
  }

  Future<void> remove(String rid) async {
    await ref.read(transactionRepositoryProvider).delete(rid);
    _invalidateDerived();
    await future;
  }

  Future<void> transfer({
    required String fromWalletRid,
    required String toWalletRid,
    required int amount,
    String? note,
    DateTime? occurredOn,
  }) async {
    await ref.read(transactionRepositoryProvider).transfer(
          fromWalletRid: fromWalletRid,
          toWalletRid: toWalletRid,
          amount: amount,
          note: note,
          occurredOn: occurredOn,
        );
    _invalidateDerived();
    await future;
  }
}

final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, List<Transaction>>(
        TransactionsController.new);
