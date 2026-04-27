import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _handlersConfigured = false;
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      await _requestNotificationPermission();
      await configureMessageHandlers();
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('FCM initialize error=$error');
      debugPrint('FCM initialize stack=$stackTrace');
    }
  }

  Future<void> registerCurrentToken(String accessToken) async {
    if (accessToken.trim().isEmpty) {
      debugPrint('FCM register skipped: empty access token');
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM getToken returned null or empty');
        return;
      }

      await _registerToken(
        accessToken: accessToken,
        tokenPush: token,
      );
    } catch (error, stackTrace) {
      debugPrint('FCM get/register token error=$error');
      debugPrint('FCM get/register token stack=$stackTrace');
    }
  }

  void listenTokenRefresh(String accessToken) {
    _tokenRefreshSubscription?.cancel();

    if (accessToken.trim().isEmpty) {
      debugPrint('FCM token refresh listener skipped: empty access token');
      return;
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) async {
        debugPrint('FCM token refreshed');
        await _registerToken(
          accessToken: accessToken,
          tokenPush: token,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh error=$error');
        debugPrint('FCM token refresh stack=$stackTrace');
      },
    );
  }

  Future<void> configureMessageHandlers() async {
    if (_handlersConfigured) return;
    _handlersConfigured = true;

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM onMessage id=${message.messageId}');
      debugPrint('FCM onMessage notification=${message.notification?.title}');
      debugPrint('FCM onMessage data=${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM onMessageOpenedApp data=${message.data}');
      _handleNotificationTap(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM getInitialMessage data=${initialMessage.data}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(initialMessage);
      });
    }
  }

  Future<void> stopTokenRefreshListener() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  Future<void> _requestNotificationPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'FCM permission status=${settings.authorizationStatus.name}',
    );
  }

  Future<void> _registerToken({
    required String accessToken,
    required String tokenPush,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/seguimiento/dispositivos-push',
    );

    final body = <String, String>{
      'token_push': tokenPush,
      'plataforma': _platformName(),
      'proveedor': 'FCM',
    };

    try {
      debugPrint('FCM registering token endpoint=$uri');
      debugPrint('FCM register body=${jsonEncode(body)}');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint(
        'FCM register status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('FCM register failed but login continues');
      }
    } catch (error, stackTrace) {
      debugPrint('FCM register request error=$error');
      debugPrint('FCM register request stack=$stackTrace');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final idNotificacion = data['id_notificacion']?.toString();
    final idIncidente = data['id_incidente']?.toString();
    final tipo = data['tipo_notificacion']?.toString();

    debugPrint(
      'FCM notification tap id_notificacion=$idNotificacion '
      'id_incidente=$idIncidente tipo_notificacion=$tipo',
    );

    if (idIncidente == null || idIncidente.isEmpty) {
      debugPrint('FCM tap without id_incidente; navigation skipped');
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('FCM navigator not ready for id_incidente=$idIncidente');
      return;
    }

    // TODO: navegar al detalle directo cuando exista una ruta que cargue
    // el incidente por id_incidente. Por ahora abrimos el listado del cliente.
    navigator.pushNamed('/client-incidents');
  }

  String _platformName() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'ANDROID';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return 'IOS';
    }
    return 'WEB';
  }
}
