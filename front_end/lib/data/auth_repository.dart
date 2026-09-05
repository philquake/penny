import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/token.dart';
import '../models/user.dart';

/// Wraps POST /auth/signup and POST /auth/login.
///
/// NOTE: the backend has no GET /auth/me (or /users/me) endpoint yet —
/// login only returns a Token, not the user's profile. That means after
/// a fresh login (not signup), this app has no way to fetch full_name or
/// created_at for the Settings screen. See session.dart for how that gap
/// is worked around for now; the real fix is adding that endpoint.
class AuthRepository {
  final ApiClient _client;
  const AuthRepository(this._client);

  Future<User> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.dio.post(
      '/auth/signup',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      },
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Token> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post(
      '/auth/login',
      data: {
        'username': email,
        'password': password,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return Token.fromJson(response.data as Map<String, dynamic>);
  }
}