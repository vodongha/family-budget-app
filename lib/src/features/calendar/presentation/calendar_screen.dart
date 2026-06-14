import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../../../core/responsive.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/application/wallet_scope.dart';
import '../../wallets/presentation/scope_toggle.dart';
import '../application/calendar_controller.dart';

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

  /// Short money label for a calendar cell, e.g. 20000 → "20k", 1500000 → "1.5tr".
  static String _compact(int v) {
    if (v >= 1000000) {
      final double m = v / 1000000;
      return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}tr';
    }
    if (v >= 1000) {
      return '${(v / 1000).round()}k';
    }
    return '$v';
  }

  /// Group a month's income/expense transactions by day (transfers excluded).
  Map<DateTime, List<Transaction>> _byDay(List<Transaction> txns) {
    final Map<DateTime, List<Transaction>> map = {};
    for (final t in txns) {
      if (t.type.isTransfer) {
        continue;
      }
      map.putIfAbsent(_dayOnly(t.occurredOn), () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final WalletScope scope = ref.watch(walletScopeProvider);
    final AsyncValue<List<Transaction>> monthly = ref.watch(
      monthTransactionsProvider(
        (year: _focused.year, month: _focused.month, scope: scope.api),
      ),
    );

    final Map<DateTime, List<Transaction>> byDay =
        monthly.maybeWhen(data: _byDay, orElse: () => const {});
    final List<Transaction> dayTxns = byDay[_dayOnly(_selected)] ?? const [];
    final int dayExpense = dayTxns
        .where((x) => x.type == TransactionType.expense)
        .fold(0, (a, x) => a + x.amount);
    final int dayIncome = dayTxns
        .where((x) => x.type == TransactionType.income)
        .fold(0, (a, x) => a + x.amount);

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
                  int net = 0;
                  for (final e in events) {
                    net += e.signedAmount;
                  }
                  final Color color = net >= 0 ? Colors.green : Colors.red;
                  final String label =
                      '${net >= 0 ? '+' : '−'}${_compact(net.abs())}';
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
                  Row(
                    children: [
                      Text('+${Money.format(dayIncome)}',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Text('−${Money.format(dayExpense)}',
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: monthly.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
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
        '${income ? '+' : '−'}${Money.format(txn.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: (txn.type.isTransfer || !txn.canEdit)
          ? null
          : () => context.push('/transactions/edit', extra: txn),
    );
  }
}
