import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';
import '../domain/auth_user.dart';

/// Talks to the backend's `/auth/*` endpoints. Owns nothing stateful beyond
/// the token store; controllers hold the in-memory session.
class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  /// OAuth2 password flow — the backend expects form-encoded `username`/`password`.
  Future<void> login(String email, String password) async {
    try {
      final Response<dynamic> res = await _dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Registers a brand-new family; the registrant becomes its **owner**.
  /// The backend does not auto-login on register, so we log in afterwards.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String familyName,
  }) async {
    try {
      await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'display_name': displayName,
        'family_name': familyName,
      });
    } catch (e) {
      throw toApiException(e);
    }
    await login(email, password);
  }

  Future<AuthUser> me() async {
    try {
      final Response<dynamic> res = await _dio.get('/auth/me');
      return AuthUser.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<String?> readToken() => _storage.read();

  Future<void> logout() => _storage.clear();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
