import 'package:flutter/foundation.dart';

import 'token_storage.dart';
import 'api_client.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }
}

final apiClient = ApiClient(
  tokenStorage: const TokenStorage(),
  baseUrl: ApiConfig.baseUrl,
);
