import 'package:flutter/foundation.dart';

import '../../../core/notifications/push_notification_service.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';
import 'auth_service.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  authenticating,
  authenticated,
}

class AuthState extends ChangeNotifier {
  final AuthRepository _repository;

  AuthStatus status = AuthStatus.checking;
  AuthUser? user;
  String? errorMessage;

  AuthState({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  String? get accessToken => _repository.currentToken;

  bool get isLoading {
    return status == AuthStatus.checking || status == AuthStatus.authenticating;
  }

  Future<void> restoreSession() async {
    status = AuthStatus.checking;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _repository.restoreSession();
      user = session?.user;
      status = session == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      if (session != null) {
        await _configurePushNotifications(session.accessToken);
      }
    } catch (_) {
      user = null;
      status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    status = AuthStatus.authenticating;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _repository.login(
        email: email,
        password: password,
        rememberSession: rememberSession,
      );

      await _configurePushNotifications(session.accessToken);

      user = session.user;
      status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      user = null;
      errorMessage = error.message;
    } catch (_) {
      user = null;
      errorMessage = 'No se pudo iniciar sesión. Intenta nuevamente.';
    }

    status = AuthStatus.unauthenticated;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.instance.stopTokenRefreshListener();
    } catch (error, stackTrace) {
      debugPrint('FCM stop token listener error=$error');
      debugPrint('FCM stop token listener stack=$stackTrace');
    } finally {
      await _repository.logout();
      user = null;
      errorMessage = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _configurePushNotifications(String accessToken) async {
    try {
      final pushService = PushNotificationService.instance;
      await pushService.initialize();
      await pushService.registerCurrentToken(accessToken);
      pushService.listenTokenRefresh(accessToken);
    } catch (error, stackTrace) {
      debugPrint('FCM auth integration error=$error');
      debugPrint('FCM auth integration stack=$stackTrace');
    }
  }
}
