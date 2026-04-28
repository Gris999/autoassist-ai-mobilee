import '../../../core/storage/token_storage.dart';
import '../domain/auth_user.dart';
import 'auth_service.dart';

class AuthSession {
  final String accessToken;
  final AuthUser user;
  final bool rememberSession;

  const AuthSession({
    required this.accessToken,
    required this.user,
    required this.rememberSession,
  });
}

class AuthRepository {
  final AuthService _service;

  String? _sessionToken;
  AuthUser? _sessionUser;

  AuthRepository({AuthService? service}) : _service = service ?? AuthService();

  String? get currentToken => _sessionToken;

  AuthUser? get currentUser => _sessionUser;

  Future<RegisterClientResponse> registerClient({
    required String nombres,
    required String apellidos,
    required String celular,
    required String email,
    required String password,
  }) {
    return _service.registerClient(
      nombres: nombres,
      apellidos: apellidos,
      celular: celular,
      email: email,
      password: password,
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    final token = await _service.login(email: email, password: password);

    try {
      final user = await _service.me(token);
      _sessionToken = token;
      _sessionUser = user;

      if (rememberSession) {
        await TokenStorage.saveToken(token);
        await TokenStorage.saveUser(user);
        await TokenStorage.saveRememberSession(true);
      } else {
        await TokenStorage.clearSession();
      }

      return AuthSession(
        accessToken: token,
        user: user,
        rememberSession: rememberSession,
      );
    } catch (_) {
      _sessionToken = null;
      _sessionUser = null;
      await TokenStorage.clearSession();
      rethrow;
    }
  }

  Future<AuthSession?> restoreSession() async {
    final rememberSession = await TokenStorage.getRememberSession();
    if (!rememberSession) return null;

    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final user = await _service.me(token);
      _sessionToken = token;
      _sessionUser = user;
      await TokenStorage.saveUser(user);

      return AuthSession(
        accessToken: token,
        user: user,
        rememberSession: true,
      );
    } catch (_) {
      _sessionToken = null;
      _sessionUser = null;
      await TokenStorage.clearSession();
      rethrow;
    }
  }

  Future<void> logout() async {
    final token = _sessionToken ?? await TokenStorage.getToken();

    try {
      if (token != null && token.isNotEmpty) {
        await _service.logout(token);
      }
    } catch (_) {
      // Logout must always remove the local session, even if the server fails.
    } finally {
      _sessionToken = null;
      _sessionUser = null;
      await TokenStorage.clearSession();
    }
  }
}
