import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../data/calendar_stats_repository.dart';
import '../domain/day_total.dart';

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

/// Per-day income/expense totals for the month, converted to the chosen display
/// currency on the backend, keyed by day. Drives the calendar's net markers and
/// day summary so they read in one currency even when wallets mix currencies.
final calendarStatsProvider =
    FutureProvider.family<Map<DateTime, DayTotal>, MonthKey>((ref, k) async {
  final String currency = ref.watch(displayCurrencyControllerProvider);
  final List<DayTotal> days =
      await ref.read(calendarStatsRepositoryProvider).month(
            year: k.year,
            month: k.month,
            scope: k.scope,
            displayCurrency: currency,
          );
  return {for (final DayTotal d in days) d.date: d};
});
