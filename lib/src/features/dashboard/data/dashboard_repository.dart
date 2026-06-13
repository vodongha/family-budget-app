import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  /// [scope] is the API value (`all` / `family` / `personal`).
  Future<DashboardSummary> summary({String scope = 'all'}) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/dashboard/summary',
        queryParameters: {'scope': scope},
      );
      return DashboardSummary.fromJson(
          (res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});
