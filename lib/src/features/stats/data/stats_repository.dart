import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/prefs.dart';
import '../domain/category_slice.dart';
import '../domain/monthly_point.dart';

class StatsRepository {
  StatsRepository(this._dio);

  final Dio _dio;

  Future<List<MonthlyPoint>> monthly({
    int months = 6,
    String scope = 'all',
    String displayCurrency = 'VND',
  }) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/stats/monthly',
        queryParameters: {
          'months': months,
          'scope': scope,
          'display_currency': displayCurrency,
        },
      );
      return (res.data as List)
          .map((e) => MonthlyPoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Totals grouped by category for one [kind] (`expense`/`income`), sorted by
  /// amount descending; the last slice may be the uncategorized bucket.
  Future<List<CategorySlice>> byCategory({
    String kind = 'expense',
    int months = 6,
    String scope = 'all',
    String displayCurrency = 'VND',
  }) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/stats/by-category',
        queryParameters: {
          'kind': kind,
          'months': months,
          'scope': scope,
          'display_currency': displayCurrency,
        },
      );
      return (res.data as List)
          .map(
              (e) => CategorySlice.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(dioProvider));
});

/// Query key for the monthly provider: (months window, scope).
typedef MonthlyStatsQuery = ({int months, String scope});

/// Monthly points for the given window + scope, in the chosen display currency.
final monthlyStatsProvider =
    FutureProvider.family<List<MonthlyPoint>, MonthlyStatsQuery>((ref, q) {
  final String currency = ref.watch(displayCurrencyControllerProvider);
  return ref
      .watch(statsRepositoryProvider)
      .monthly(months: q.months, scope: q.scope, displayCurrency: currency);
});

/// Query key for the by-category provider: ((`expense`/`income`), months, scope).
typedef CategoryStatsQuery = ({String kind, int months, String scope});

/// Category totals for the given kind + window + scope, in the display currency.
final categoryStatsProvider =
    FutureProvider.family<List<CategorySlice>, CategoryStatsQuery>((ref, q) {
  final String currency = ref.watch(displayCurrencyControllerProvider);
  return ref.watch(statsRepositoryProvider).byCategory(
        kind: q.kind,
        months: q.months,
        scope: q.scope,
        displayCurrency: currency,
      );
});
