import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._dio);

  final Dio _dio;
  static final DateFormat _ymd = DateFormat('yyyy-MM-dd');

  Future<List<Transaction>> list({
    String? walletRid,
    String scope = 'all',
    int limit = 50,
    TransactionType? type,
    String? categoryRid,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/transactions',
        queryParameters: {
          if (walletRid != null) 'wallet_rid': walletRid,
          'scope': scope,
          'limit': limit,
          if (type != null) 'type': type.api,
          if (categoryRid != null) 'category_rid': categoryRid,
          if (dateFrom != null) 'date_from': _ymd.format(dateFrom),
          if (dateTo != null) 'date_to': _ymd.format(dateTo),
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

  Future<Transaction> update({
    required String rid,
    required String walletRid,
    required TransactionType type,
    required int amount,
    String? note,
    String? categoryRid,
    DateTime? occurredOn,
  }) async {
    try {
      final Response<dynamic> res =
          await _dio.patch('/transactions/$rid', data: {
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

  Future<void> delete(String rid) async {
    try {
      await _dio.delete('/transactions/$rid');
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Move money between two wallets (creates the two linked transfer legs).
  Future<void> transfer({
    required String fromWalletRid,
    required String toWalletRid,
    required int amount,
    String? note,
    DateTime? occurredOn,
  }) async {
    try {
      await _dio.post('/transfers', data: {
        'from_wallet_rid': fromWalletRid,
        'to_wallet_rid': toWalletRid,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        if (occurredOn != null) 'occurred_on': _ymd.format(occurredOn),
      });
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(dioProvider));
});
