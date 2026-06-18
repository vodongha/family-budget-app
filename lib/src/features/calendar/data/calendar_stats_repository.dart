import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/day_total.dart';

class CalendarStatsRepository {
  CalendarStatsRepository(this._dio);

  final Dio _dio;

  /// Per-day income/expense totals for a month, in [displayCurrency].
  Future<List<DayTotal>> month({
    required int year,
    required int month,
    String scope = 'all',
    String displayCurrency = 'VND',
  }) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/stats/calendar',
        queryParameters: {
          'year': year,
          'month': month,
          'scope': scope,
          'display_currency': displayCurrency,
        },
      );
      return (res.data as List)
          .map((e) => DayTotal.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final calendarStatsRepositoryProvider =
    Provider<CalendarStatsRepository>((ref) {
  return CalendarStatsRepository(ref.watch(dioProvider));
});
