import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ServerSettings {
  static const _key = 'server_address';
  static const _defaultHttpPort = 8000;

  /// Accepts "100.x.x.x:8000", "http://host:8000" or "https://host".
  /// Returns a normalized base URL, or null if the input can't be used.
  static String? normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    if (!value.contains('://')) {
      // An explicit port means local plain-HTTP dev (for example 100.x.x.x:8000).
      // Anything else is assumed to be HTTPS on 443, such as a tailscale serve URL.
      final hasPort = RegExp(r':\d+$').hasMatch(value);
      value = '${hasPort ? 'http' : 'https'}://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'http' ? _defaultHttpPort : null);

    return Uri(scheme: uri.scheme, host: uri.host, port: port).toString();
  }

  /// Applies a server address typed by the user and remembers it.
  /// Returns an error message, or null on success.
  static Future<String?> apply(String input) async {
    final normalized = normalize(input);
    if (normalized == null) {
      return 'Enter a valid server address, for example 100.x.x.x:8000.';
    }

    apiClient.setBaseUrl(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalized);
    return null;
  }

  /// Restores the last saved server before the first request is made.
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final normalized = saved == null ? null : normalize(saved);
    if (normalized != null) {
      apiClient.setBaseUrl(normalized);
    }
  }
}