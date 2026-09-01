import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _tokenKey = 'access_token';

  final FlutterSecureStorage _storage;

  const TokenStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<void> saveToken(String token) async {
    await _storage.write(
      key: _tokenKey,
      value: token,
    );
  }

  Future<String?> getToken() async {
    return _storage.read(
      key: _tokenKey,
    );
  }

  Future<void> deleteToken() async {
    await _storage.delete(
      key: _tokenKey,
    );
  }
}

