import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/token.dart';
import '../models/user.dart';

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

  Future<User> me() async {
    final response = await _client.dio.get('/auth/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}