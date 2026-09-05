import 'package:dio/dio.dart';

import 'token_storage.dart';

class ApiClient {
  late final Dio dio;

  final TokenStorage tokenStorage;
  final Future<void> Function()? onUnauthorized;

  ApiClient({
    required this.tokenStorage,
    this.onUnauthorized,
    required String baseUrl,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        onError: (error, handler) async {
          final isAuthRequest = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 && !isAuthRequest) {
            await tokenStorage.deleteToken();

            if (onUnauthorized != null) {
              await onUnauthorized!();
            }
          }

          handler.next(error);
        },
      ),
    );
  }
}
