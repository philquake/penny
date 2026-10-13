import 'package:dio/dio.dart';

import 'token_storage.dart';

class ApiClient {
  /// Endpoints where a 401 means "wrong credentials", not "session expired".
  static const _credentialEndpoints = {'/auth/login', '/auth/signup'};

  /// Key under which the token used for a request is kept, so a 401 can be
  /// matched against the token that is currently stored.
  static const _sentTokenKey = 'sent_token';

  late final Dio dio;

  final TokenStorage tokenStorage;
  Future<void> Function()? onUnauthorized;

  /// Serializes session-expiry handling so concurrent 401s signal it once.
  Future<void>? _expiring;

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
            options.extra[_sentTokenKey] = token;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !_credentialEndpoints.contains(error.requestOptions.path)) {
            await _handleExpiredToken(error.requestOptions.extra[_sentTokenKey]);
          }
          handler.next(error);
        },
      ),
    );
  }

  /// The server currently used for requests.
  String get baseUrl => dio.options.baseUrl;

  /// Points subsequent requests at a different server. Takes effect on the
  /// next request; requests already in flight keep their original target.
  void setBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  /// Clears the stored token only if it is still the one that was rejected.
  /// A 401 from an old token must not delete a token saved by a later sign-in.
  Future<void> _handleExpiredToken(Object? sentToken) async {
    if (sentToken is! String) return;

    final current = await tokenStorage.getToken();
    if (current != sentToken) return;

    _expiring ??= _expire().whenComplete(() => _expiring = null);
    await _expiring;
  }

  Future<void> _expire() async {
    await tokenStorage.deleteToken();
    await onUnauthorized?.call();
  }
}