import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/budget.dart';

class BudgetRepository {
  BudgetRepository(this._dio);

  final Dio _dio;

  /// [scope] is `personal` or `family`. Limits/spend come back in
  /// [displayCurrency]; an [amount] sent to the API is in [displayCurrency] too.
  Future<List<Budget>> list({
    String scope = 'personal',
    String displayCurrency = 'VND',
  }) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/budgets',
        queryParameters: {'scope': scope, 'display_currency': displayCurrency},
      );
      return (res.data as List)
          .map((e) => Budget.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> create({
    required String categoryRid,
    required int amount,
    String scope = 'personal',
    String displayCurrency = 'VND',
  }) async {
    try {
      await _dio.post(
        '/budgets',
        queryParameters: {'scope': scope, 'display_currency': displayCurrency},
        data: {'category_rid': categoryRid, 'amount': amount},
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> update({
    required String rid,
    required int amount,
    String displayCurrency = 'VND',
  }) async {
    try {
      await _dio.patch(
        '/budgets/$rid',
        queryParameters: {'display_currency': displayCurrency},
        data: {'amount': amount},
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(String rid) async {
    try {
      await _dio.delete('/budgets/$rid');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(dioProvider));
});
