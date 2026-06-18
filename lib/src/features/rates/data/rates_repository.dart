import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/rates_info.dart';

class RatesRepository {
  RatesRepository(this._dio);

  final Dio _dio;

  /// Status of the stored exchange rates (when last refreshed).
  Future<RatesInfo> get() async {
    try {
      final Response<dynamic> res = await _dio.get('/rates');
      return RatesInfo.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Pull a fresh set of rates from the source now. `503` if it can't be reached.
  Future<RatesInfo> refresh() async {
    try {
      final Response<dynamic> res = await _dio.post('/rates/refresh');
      return RatesInfo.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final ratesRepositoryProvider = Provider<RatesRepository>((ref) {
  return RatesRepository(ref.watch(dioProvider));
});

/// Current exchange-rate status (last-updated time + count).
final ratesInfoProvider = FutureProvider<RatesInfo>((ref) {
  return ref.watch(ratesRepositoryProvider).get();
});
