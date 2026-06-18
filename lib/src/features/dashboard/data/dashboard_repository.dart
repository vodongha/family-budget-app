import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  /// [scope] is the API value (`all` / `family` / `personal`).
  /// [displayCurrency] is the currency the totals are rendered in (per-wallet
  /// balances stay in their own currency).
  Future<DashboardSummary> summary({
    String scope = 'all',
    String displayCurrency = 'VND',
  }) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/dashboard/summary',
        queryParameters: {
          'scope': scope,
          'display_currency': displayCurrency,
        },
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
