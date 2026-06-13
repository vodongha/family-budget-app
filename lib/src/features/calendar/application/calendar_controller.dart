import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';

/// Query key: the month to load plus the active wallet scope.
typedef MonthKey = ({int year, int month, String scope});

/// All transactions in the given month (used by the calendar, grouped by day).
final monthTransactionsProvider =
    FutureProvider.family<List<Transaction>, MonthKey>((ref, k) {
  final DateTime from = DateTime(k.year, k.month, 1);
  final DateTime to = DateTime(k.year, k.month + 1, 0); // last day of the month
  return ref.read(transactionRepositoryProvider).list(
        scope: k.scope,
        dateFrom: from,
        dateTo: to,
        limit: 500,
      );
});
