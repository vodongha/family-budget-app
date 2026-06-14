import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/wallet.dart';

class WalletRepository {
  WalletRepository(this._dio);

  final Dio _dio;

  /// Wallets the caller may see. [scope] is the API value (`all` / `family` /
  /// `personal`); defaults to everything visible so pickers can list them all.
  Future<List<Wallet>> list({String scope = 'all'}) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/wallets',
        queryParameters: {'scope': scope},
      );
      return (res.data as List)
          .map((e) => Wallet.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Create a wallet. [visibility] is `family` (shared) or `personal` (private).
  Future<Wallet> create(
    String name, {
    String visibility = 'family',
    String? icon,
    String? color,
  }) async {
    try {
      final Response<dynamic> res = await _dio.post(
        '/wallets',
        data: {
          'name': name,
          'visibility': visibility,
          if (icon != null) 'icon': icon,
          if (color != null) 'color': color,
        },
      );
      return Wallet.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Edit a wallet's name/icon/colour (only the provided fields change).
  /// Family wallet → family owner; personal wallet → its owner.
  Future<Wallet> update(
    String rid, {
    String? name,
    String? icon,
    String? color,
  }) async {
    try {
      final Response<dynamic> res = await _dio.patch(
        '/wallets/$rid',
        data: {
          if (name != null) 'name': name,
          if (icon != null) 'icon': icon,
          if (color != null) 'color': color,
        },
      );
      return Wallet.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Delete a wallet and all its transactions (owner-only). Returns the number
  /// of transactions removed.
  Future<int> delete(String rid) async {
    try {
      final Response<dynamic> res = await _dio.delete('/wallets/$rid');
      return ((res.data as Map)['deleted_transactions'] ?? 0) as int;
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(dioProvider));
});
