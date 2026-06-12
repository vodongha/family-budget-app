import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/wallet.dart';

class WalletRepository {
  WalletRepository(this._dio);

  final Dio _dio;

  Future<List<Wallet>> list() async {
    try {
      final Response<dynamic> res = await _dio.get('/wallets');
      return (res.data as List)
          .map((e) => Wallet.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<Wallet> create(String name) async {
    try {
      final Response<dynamic> res =
          await _dio.post('/wallets', data: {'name': name});
      return Wallet.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(dioProvider));
});
