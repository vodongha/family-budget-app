import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/monthly_point.dart';

class StatsRepository {
  StatsRepository(this._dio);

  final Dio _dio;

  Future<List<MonthlyPoint>> monthly({int months = 6}) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/stats/monthly',
        queryParameters: {'months': months},
      );
      return (res.data as List)
          .map((e) => MonthlyPoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(dioProvider));
});

/// Monthly points for the given window (number of months).
final monthlyStatsProvider =
    FutureProvider.family<List<MonthlyPoint>, int>((ref, months) {
  return ref.watch(statsRepositoryProvider).monthly(months: months);
});
