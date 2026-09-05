import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/token_storage.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

enum SessionStatus { bootstrapping, signedOut, signedIn }

class SessionState {
  final SessionStatus status;
  final User? user;
  final String? error;

  const SessionState({required this.status, this.user, this.error});

  const SessionState.bootstrapping() : this(status: SessionStatus.bootstrapping);
  const SessionState.signedOut({String? error})
      : this(status: SessionStatus.signedOut, error: error);
  const SessionState.signedIn(User user)
      : this(status: SessionStatus.signedIn, user: user);
}

/// Owns sign-in/sign-out and the current user.
///
/// NOTE: because the backend has no GET /auth/me, a plain login (as
/// opposed to signup) can't fetch full_name/created_at — the JWT only
/// carries user_id and role (see core/security.py's create_access_token).
/// Until that endpoint exists, a login-only session uses a stub User
/// built from the email typed at the login screen, clearly marked below.
/// Signup sessions get the real profile since /auth/signup returns it.
class SessionController extends StateNotifier<SessionState> {
  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;

  SessionController(this._authRepository, this._tokenStorage)
      : super(const SessionState.bootstrapping()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      state = const SessionState.signedOut();
      return;
    }
    // A token exists from a previous session, but with no /auth/me we
    // can't re-fetch the profile — fall back to a stub until that
    // endpoint lands. The app still works; Settings will show a
    // placeholder name.
    state = SessionState.signedIn(_stubUser());
  }

  Future<String?> login({required String email, required String password}) async {
    try {
      final token = await _authRepository.login(email: email, password: password);
      await _tokenStorage.saveToken(token.accessToken);
      state = SessionState.signedIn(_stubUser(email: email));
      return null;
    } on DioException catch (e) {
      return _messageFor(e);
    }
  }

  Future<String?> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final user = await _authRepository.signup(
        email: email,
        password: password,
        fullName: fullName,
      );
      // Signup doesn't return a token — log in immediately after so the
      // person isn't asked to type their password twice in a row.
      final token = await _authRepository.login(email: email, password: password);
      await _tokenStorage.saveToken(token.accessToken);
      state = SessionState.signedIn(user);
      return null;
    } on DioException catch (e) {
      return _messageFor(e);
    }
  }

  Future<void> signOut() async {
    await _tokenStorage.deleteToken();
    state = const SessionState.signedOut();
  }

  User _stubUser({String? email}) => User(
        id: 0,
        email: email ?? state.user?.email ?? '',
        fullName: (email ?? '').split('@').first,
        createdAt: DateTime.now(),
      );

  String _messageFor(DioException e) {
    if (e.response?.statusCode == 401) return 'Incorrect email or password.';
    if (e.response?.statusCode == 400) return 'That email is already registered.';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Couldn\'t reach the server. Check the address and your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final tokenStorageProvider = Provider((ref) => const TokenStorage());
final apiClientProvider = Provider<ApiClient>((ref) => apiClient);
final authRepositoryProvider =
    Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));

final sessionProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStorageProvider),
  ),
);