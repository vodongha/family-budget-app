import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'token_storage.dart';

/// Thrown by repositories for any non-2xx response, carrying a user-facing
/// message extracted from the FastAPI error body (`detail`).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Turns a Dio failure into an [ApiException] with a readable message.
ApiException toApiException(Object error) {
  if (error is DioException) {
    final dynamic data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return ApiException(data['detail'].toString(),
          statusCode: error.response?.statusCode);
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return ApiException('Cannot reach the server. Is the backend running?');
    }
    return ApiException(
      error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
    );
  }
  return ApiException(error.toString());
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
    ),
  );

  return dio;
});
