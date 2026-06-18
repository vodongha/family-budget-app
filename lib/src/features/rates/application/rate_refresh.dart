import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../budgets/application/budgets_controller.dart';
import '../../calendar/application/calendar_controller.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../stats/data/stats_repository.dart';
import '../data/rates_repository.dart';

/// Pull fresh exchange rates, then invalidate everything whose figures are
/// converted with them, so the UI reflects the new rates immediately. Throws
/// (via the repository) if the source is unreachable — the caller shows it.
Future<void> refreshRates(WidgetRef ref) async {
  await ref.read(ratesRepositoryProvider).refresh();
  ref.invalidate(ratesInfoProvider);
  ref.invalidate(dashboardControllerProvider);
  ref.invalidate(monthlyStatsProvider);
  ref.invalidate(categoryStatsProvider);
  ref.invalidate(budgetsControllerProvider);
  ref.invalidate(calendarStatsProvider);
}
