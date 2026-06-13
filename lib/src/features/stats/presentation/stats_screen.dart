import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../dashboard/domain/dashboard_summary.dart';
import '../../wallets/application/wallet_scope.dart';
import '../data/stats_repository.dart';
import '../domain/category_slice.dart';
import '../domain/monthly_point.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final WalletScope scope = ref.watch(walletScopeProvider);
    final AsyncValue<List<MonthlyPoint>> monthly =
        ref.watch(monthlyStatsProvider((months: _months, scope: scope.api)));
    final AsyncValue<DashboardSummary> summary =
        ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.statistics)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3M')),
                ButtonSegment(value: 6, label: Text('6M')),
                ButtonSegment(value: 12, label: Text('12M')),
              ],
              selected: {_months},
              onSelectionChanged: (s) => setState(() => _months = s.first),
            ),
          ),
          const SizedBox(height: 20),
          _ChartCard(
            title: t.monthlyTrend,
            child: monthly.when(
              loading: () => const _ChartLoading(),
              error: (e, _) => _ChartMessage('$e'),
              data: (points) => _MonthlyBars(points: points),
            ),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: t.incomeVsExpense,
            child: monthly.when(
              loading: () => const _ChartLoading(),
              error: (e, _) => _ChartMessage('$e'),
              data: (points) => _IncomeExpenseDonut(
                income: points.fold(0, (a, p) => a + p.income),
                expense: points.fold(0, (a, p) => a + p.expense),
                incomeLabel: t.income,
                expenseLabel: t.expense,
                emptyLabel: t.noData,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: t.balanceByWallet,
            child: summary.when(
              loading: () => const _ChartLoading(),
              error: (e, _) => _ChartMessage('$e'),
              data: (s) => _WalletBars(
                wallets: s.wallets,
                emptyLabel: t.noData,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ByCategoryCard(months: _months, scope: scope.api),
        ],
      ),
    );
  }
}

/// Spending/earning broken down by category, with an expense/income toggle.
class _ByCategoryCard extends ConsumerStatefulWidget {
  const _ByCategoryCard({required this.months, required this.scope});
  final int months;
  final String scope;

  @override
  ConsumerState<_ByCategoryCard> createState() => _ByCategoryCardState();
}

class _ByCategoryCardState extends ConsumerState<_ByCategoryCard> {
  String _kind = 'expense';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AsyncValue<List<CategorySlice>> slices = ref.watch(
      categoryStatsProvider(
        (kind: _kind, months: widget.months, scope: widget.scope),
      ),
    );

    return _ChartCard(
      title: t.spendingByCategory,
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'expense', label: Text(t.expense)),
              ButtonSegment(value: 'income', label: Text(t.income)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          slices.when(
            loading: () => const _ChartLoading(),
            error: (e, _) => _ChartMessage('$e'),
            data: (data) => _CategoryDonut(slices: data, emptyLabel: t.noData),
          ),
        ],
      ),
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.slices, required this.emptyLabel});
  final List<CategorySlice> slices;
  final String emptyLabel;

  // Fallback palette for slices without a stored colour.
  static const List<Color> _palette = [
    Color(0xFF5B8DEF),
    Color(0xFFEF767A),
    Color(0xFF49C5B6),
    Color(0xFFF2A65A),
    Color(0xFF9B6DD6),
    Color(0xFF6DBE6A),
    Color(0xFFE4A0C7),
    Color(0xFF7C8CA0),
  ];

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return _ChartMessage(emptyLabel);
    }
    final AppLocalizations t = AppLocalizations.of(context);
    final int total = slices.fold(0, (a, s) => a + s.amount);
    final List<Color> colors = [
      for (int i = 0; i < slices.length; i++)
        slices[i].colorOr(_palette[i % _palette.length]),
    ];

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                for (int i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].amount.toDouble(),
                    color: colors[i],
                    radius: 44,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < slices.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _CategoryLegend(
            color: colors[i],
            icon: slices[i].icon,
            label: slices[i].label(t),
            amount: slices[i].amount,
            percent: total == 0 ? 0 : slices[i].amount / total,
          ),
        ],
      ],
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({
    required this.color,
    required this.icon,
    required this.label,
    required this.amount,
    required this.percent,
  });
  final Color color;
  final String? icon;
  final String label;
  final int amount;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        if (icon != null && icon!.isNotEmpty) ...[
          Text(icon!, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        Text(
          '${(percent * 100).round()}%',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(width: 10),
        Text(Money.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.points});
  final List<MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final double maxY = points
        .map((p) => (p.income > p.expense ? p.income : p.expense).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    if (maxY == 0) {
      return _ChartMessage(AppLocalizations.of(context).noData);
    }
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                Money.format(rod.toY.toInt()),
                const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[i].shortLabel,
                        style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: points[i].income.toDouble(),
                    color: Colors.green,
                    width: 7,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: points[i].expense.toDouble(),
                    color: Colors.red,
                    width: 7,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _IncomeExpenseDonut extends StatelessWidget {
  const _IncomeExpenseDonut({
    required this.income,
    required this.expense,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.emptyLabel,
  });

  final int income;
  final int expense;
  final String incomeLabel;
  final String expenseLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (income == 0 && expense == 0) {
      return _ChartMessage(emptyLabel);
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: [
                PieChartSectionData(
                  value: income.toDouble(),
                  color: Colors.green,
                  radius: 44,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: expense.toDouble(),
                  color: Colors.red,
                  radius: 44,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Legend(color: Colors.green, label: incomeLabel, amount: income),
        const SizedBox(height: 6),
        _Legend(color: Colors.red, label: expenseLabel, amount: expense),
      ],
    );
  }
}

class _WalletBars extends StatelessWidget {
  const _WalletBars({required this.wallets, required this.emptyLabel});
  final List<dynamic> wallets; // Wallet objects from DashboardSummary
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return _ChartMessage(emptyLabel);
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double maxY = wallets
        .map((w) => (w.balance as int).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: (maxY == 0 ? 1 : maxY) * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                Money.format(rod.toY.toInt()),
                const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= wallets.length) {
                    return const SizedBox.shrink();
                  }
                  final String name = wallets[i].name as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      name.length > 8 ? '${name.substring(0, 7)}…' : name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < wallets.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (wallets[i].balance as int).toDouble(),
                    color: cs.primary,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.amount,
  });
  final Color color;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(Money.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ChartMessage extends StatelessWidget {
  const _ChartMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
}
