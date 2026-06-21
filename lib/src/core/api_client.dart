import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import 'config.dart';
import 'token_storage.dart';

/// Thrown by repositories for any non-2xx response, carrying a user-facing
/// message extracted from the FastAPI error body (`detail`).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.isConnection = false,
    this.serverDetail = false,
  });

  final String message;
  final int? statusCode;

  /// True when the request never reached the server (offline / timeout / DNS),
  /// so the UI can show a friendly "can't reach the server" screen.
  final bool isConnection;

  /// True when [message] is a meaningful, user-facing reason supplied by the
  /// server (FastAPI `detail`, e.g. "duplicate phone"). When false, [message] is
  /// only a developer-facing fallback — the UI must show a localized generic
  /// message instead (see `friendlyError`), never this raw text.
  final bool serverDetail;

  @override
  String toString() => message;
}

/// Turns a Dio failure into an [ApiException].
///
/// Important: this never surfaces Dio's verbose internal message (the "this
/// exception was thrown because the response has a status code of 500…" dump
/// that used to leak onto the login screen). A server-supplied `detail` is kept
/// (and flagged via [ApiException.serverDetail]); everything else gets a short
/// fallback and the UI localizes it through `friendlyError`.
ApiException toApiException(Object error) {
  if (error is DioException) {
    final int? code = error.response?.statusCode;
    final dynamic data = error.response?.data;
    // Only trust a server detail for client errors (4xx). A 5xx "detail" is an
    // internal failure description, not something to show the user.
    if (data is Map &&
        data['detail'] != null &&
        code != null &&
        code >= 400 &&
        code < 500) {
      return ApiException(
        data['detail'].toString(),
        statusCode: code,
        serverDetail: true,
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException('connection-error', isConnection: true);
    }
    return ApiException('request-failed', statusCode: code);
  }
  return ApiException('request-failed');
}

/// A single configured [Dio] for the whole app. An interceptor attaches the
/// bearer token (read fresh from secure storage) to every request.
final dioProvider = Provider<Dio>((ref) {
  final TokenStorage storage = ref.watch(tokenStorageProvider);

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final String? token = await storage.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // A 401 on an authenticated endpoint means our token is expired or no
        // longer valid. Drop it and reset the session so the router sends the
        // user back to `/login` to sign in again. Without this the session only
        // gets re-checked at app startup, so a token that expires mid-session
        // leaves the user "signed in" but unauthorized — every screen just
        // shows "session expired" with no way to re-authenticate.
        //
        // The auth endpoints are excluded: a 401 from `/auth/login` (or
        // register/google) is a bad-credentials error, not an expired session —
        // there is nothing to drop and the screen shows the real reason itself.
        final int? code = error.response?.statusCode;
        final String path = error.requestOptions.path;
        final bool onAuthEndpoint = path.contains('/auth/login') ||
            path.contains('/auth/register') ||
            path.contains('/auth/google');
        if (code == 401 && !onAuthEndpoint) {
          await storage.clear();
          // Re-running the auth bootstrap with no token resolves to signed-out
          // (no network call), which the router observes and redirects to login.
          ref.invalidate(authControllerProvider);
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
