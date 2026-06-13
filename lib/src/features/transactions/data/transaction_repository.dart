import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._dio);

  final Dio _dio;
  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');

  Future<List<Transaction>> list({String? walletRid, int limit = 50}) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/transactions',
        queryParameters: {
          if (walletRid != null) 'wallet_rid': walletRid,
          'limit': limit,
        },
      );
      return (res.data as List)
          .map((e) => Transaction.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<Transaction> create({
    required String walletRid,
    required TransactionType type,
    required int amount,
    String? note,
    String? categoryRid,
    DateTime? occurredOn,
  }) async {
    try {
      final Response<dynamic> res = await _dio.post('/transactions', data: {
        'wallet_rid': walletRid,
        'type': type.api,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        if (categoryRid != null) 'category_rid': categoryRid,
        if (occurredOn != null) 'occurred_on': _ymd.format(occurredOn),
      });
      return Transaction.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(dioProvider));
});
