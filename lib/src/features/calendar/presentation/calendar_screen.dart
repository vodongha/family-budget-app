import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_error_view.dart';
import '../../../core/money.dart';
import '../../../core/prefs.dart';
import '../../../core/responsive.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/application/wallet_scope.dart';
import '../../wallets/presentation/scope_toggle.dart';
import '../application/calendar_controller.dart';
import '../domain/day_total.dart';

/// A month calendar of spending: each day is marked by a dot (net income green /
/// net expense red); tapping a day lists that day's transactions below.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Short money label for a calendar cell from minor units of [currency], e.g.
  /// 20000 VND → "20k", 1500000 → "1.5tr". For a decimal currency the compaction
  /// works on the major value.
  static String _compact(int minor, String currency) {
    final num v = minor / _pow10(Money.decimalsFor(currency));
    if (v >= 1000000) {
      final double m = v / 1000000;
      return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}tr';
    }
    if (v >= 1000) {
      return '${(v / 1000).round()}k';
    }
    return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);
  }

  static int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// Group a month's transactions by day. Transfers are included so they show in
  /// the day's list, but the net markers / day totals exclude them (a transfer
  /// is not income or expense — see the marker builder and day summary).
  Map<DateTime, List<Transaction>> _byDay(List<Transaction> txns) {
    final Map<DateTime, List<Transaction>> map = {};
    for (final t in txns) {
      map.putIfAbsent(_dayOnly(t.occurredOn), () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final WalletScope scope = ref.watch(walletScopeProvider);
    final MonthKey key =
        (year: _focused.year, month: _focused.month, scope: scope.api);
    final AsyncValue<List<Transaction>> monthly =
        ref.watch(monthTransactionsProvider(key));
    // Per-day totals converted to the display currency (backend); the markers and
    // day summary read from this so they show one currency even across wallets.
    final String currency = ref.watch(displayCurrencyControllerProvider);
    final Map<DateTime, DayTotal> dayTotals =
        ref.watch(calendarStatsProvider(key)).maybeWhen(
              data: (m) => m,
              orElse: () => const <DateTime, DayTotal>{},
            );

    final Map<DateTime, List<Transaction>> byDay =
        monthly.maybeWhen(data: _byDay, orElse: () => const {});
    final List<Transaction> dayTxns = byDay[_dayOnly(_selected)] ?? const [];
    final DayTotal? dayTotal = dayTotals[_dayOnly(_selected)];

    return Scaffold(
      appBar: AppBar(title: Text(t.calendar)),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: const ScopeToggle(),
            ),
            TableCalendar<Transaction>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _focused,
              currentDay: DateTime.now(),
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (d) => isSameDay(_selected, d),
              eventLoader: (day) => byDay[_dayOnly(day)] ?? const [],
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onPageChanged: (focused) => setState(() => _focused = focused),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders<Transaction>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) {
                    return null;
                  }
                  final DayTotal? dt = dayTotals[_dayOnly(day)];
                  final int net = dt?.net ?? 0;
                  // Days with only internal transfers have transactions but no
                  // net income/expense → a neutral dot.
                  if (dt == null || net == 0) {
                    return Positioned(
                      bottom: 3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.blueGrey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  final Color color = net > 0 ? Colors.green : Colors.red;
                  final String label =
                      '${net > 0 ? '+' : '−'}${_compact(net.abs(), currency)}';
                  return Positioned(
                    bottom: 1,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Selected-day summary.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selected.year}-${_selected.month.toString().padLeft(2, '0')}-${_selected.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (dayTotal != null)
                    Row(
                      children: [
                        Text('+${Money.formatIn(dayTotal.income, currency)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Text('−${Money.formatIn(dayTotal.expense, currency)}',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: monthly.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(monthTransactionsProvider),
                ),
                data: (_) => dayTxns.isEmpty
                    ? Center(
                        child: Text(
                          t.noTransactionsThisDay,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: dayTxns.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _DayTxnTile(txn: dayTxns[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTxnTile extends StatelessWidget {
  const _DayTxnTile({required this.txn});
  final Transaction txn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final bool income = txn.type.isIncome;
    final Color color = income ? Colors.green : Colors.red;
    final String? categoryName = txn.category?.label(t);
    final String title = (txn.note == null || txn.note!.isEmpty)
        ? (categoryName ?? (income ? t.income : t.expense))
        : txn.note!;
    return ListTile(
      dense: true,
      leading: Text(txn.category?.icon ?? (income ? '＋' : '－'),
          style: const TextStyle(fontSize: 18)),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: categoryName != null ? Text(categoryName) : null,
      trailing: Text(
        '${income ? '+' : '−'}${Money.formatIn(txn.amount, txn.currency)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: (txn.type.isTransfer || !txn.canEdit)
          ? null
          : () => context.push('/transactions/edit', extra: txn),
    );
  }
}
