import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'token_storage.dart';

class ApiConfig {
  /// Fallback used before the user has saved a server address.
  /// 10.0.2.2 reaches the host machine from the Android emulator only.
  /// Physical devices must set the server on the login screen.
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}

final apiClient = ApiClient(
  tokenStorage: const TokenStorage(),
  baseUrl: ApiConfig.defaultBaseUrl,
);