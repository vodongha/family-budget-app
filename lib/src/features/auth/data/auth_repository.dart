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

  /// Registers a brand-new account (no family yet — the user creates or joins one
  /// after signing in). The backend does not auto-login on register, so we log in
  /// afterwards.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    try {
      await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'display_name': displayName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
    } catch (e) {
      throw toApiException(e);
    }
    await login(email, password);
  }

  /// Creates a family for the signed-in account (making it the owner) and stores
  /// the fresh JWT the backend returns — it carries the new family scope, so
  /// subsequent requests (and a follow-up `me()`) see the family.
  Future<void> createFamily(String name) async {
    try {
      final Response<dynamic> res =
          await _dio.post('/families', data: {'name': name});
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Delete the family (owner-only, only when no other members) and store the
  /// fresh JWT (now family-less). Personal data is kept.
  Future<void> deleteFamily() async {
    try {
      final Response<dynamic> res = await _dio.delete('/families');
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Leave the current family and store the fresh JWT (now family-less).
  Future<void> leaveFamily() async {
    try {
      final Response<dynamic> res = await _dio.post('/families/leave');
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Exchanges a Google ID token (obtained on the client) for our JWT.
  Future<void> googleLogin(String idToken) async {
    try {
      final Response<dynamic> res =
          await _dio.post('/auth/google', data: {'id_token': idToken});
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<AuthUser> me() async {
    try {
      final Response<dynamic> res = await _dio.get('/auth/me');
      return AuthUser.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Update the display name and (optional) phone. The phone is always sent so a
  /// blank value clears it; the backend validates/normalises it to E.164.
  Future<AuthUser> updateProfile({
    required String displayName,
    String? phone,
  }) async {
    try {
      final Response<dynamic> res = await _dio.patch(
        '/auth/me',
        data: {'display_name': displayName, 'phone': phone ?? ''},
      );
      return AuthUser.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Change the password (send `currentPassword`), or set the first password for
  /// a Google-only account (omit `currentPassword`).
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/change-password', data: {
        if (currentPassword != null && currentPassword.isNotEmpty)
          'current_password': currentPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Self-service account deletion (Google Play policy). Clears the local token
  /// on success so the app returns to a signed-out state.
  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/auth/me');
    } catch (e) {
      throw toApiException(e);
    }
    await _storage.clear();
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
