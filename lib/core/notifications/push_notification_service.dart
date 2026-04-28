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
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

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
      _showForegroundNotification(message);
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
    final payload = _PushPayload.fromMessage(message);

    debugPrint(
      'FCM notification tap id_notificacion=${payload.idNotificacion} '
      'id_incidente=${payload.idIncidente} '
      'tipo_notificacion=${payload.tipoNotificacion}',
    );

    _navigateFromPayload(payload);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final payload = _PushPayload.fromMessage(message);
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('FCM foreground snackbar skipped: messenger not ready');
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(payload.displayText),
          action: payload.idIncidente == null
              ? null
              : SnackBarAction(
                  label: 'Ver',
                  onPressed: () => _navigateFromPayload(payload),
                ),
        ),
      );
  }

  void _navigateFromPayload(_PushPayload payload) {
    final idIncidente = payload.idIncidente;

    if (idIncidente == null) {
      debugPrint('FCM tap without id_incidente; navigation skipped');
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('FCM navigator not ready for id_incidente=$idIncidente');
      return;
    }

    navigator.pushNamed(
      '/client-incidents',
      arguments: {
        'id_incidente': idIncidente,
        'destination': payload.destination,
      },
    );
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

class _PushPayload {
  final String? idNotificacion;
  final int? idIncidente;
  final String tipoNotificacion;
  final String titulo;
  final String mensaje;

  const _PushPayload({
    required this.idNotificacion,
    required this.idIncidente,
    required this.tipoNotificacion,
    required this.titulo,
    required this.mensaje,
  });

  factory _PushPayload.fromMessage(RemoteMessage message) {
    final data = message.data;
    final title = data['titulo']?.toString() ??
        data['title']?.toString() ??
        message.notification?.title ??
        'Notificación';
    final body = data['mensaje']?.toString() ??
        data['message']?.toString() ??
        data['body']?.toString() ??
        message.notification?.body ??
        '';

    return _PushPayload(
      idNotificacion: data['id_notificacion']?.toString(),
      idIncidente: int.tryParse(data['id_incidente']?.toString() ?? ''),
      tipoNotificacion:
          data['tipo_notificacion']?.toString().toUpperCase() ?? '',
      titulo: title,
      mensaje: body,
    );
  }

  String get displayText {
    if (mensaje.trim().isEmpty) return titulo;
    return '$titulo\n$mensaje';
  }

  String get destination {
    return switch (tipoNotificacion) {
      'TALLER_ACEPTO' ||
      'ASIGNACION_TECNICO' ||
      'TECNICO_ASIGNADO' ||
      'UNIDAD_MOVIL_ASIGNADA' ||
      'UNIDAD_ASIGNADA' ||
      'ASIGNACION_COMPLETA' =>
        'assignment',
      _ => 'detail',
    };
  }
}
