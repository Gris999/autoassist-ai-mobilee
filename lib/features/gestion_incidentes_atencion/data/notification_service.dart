import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'notification_models.dart';

class NotificationService {
  final http.Client _client;

  NotificationService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AppNotificationModel>> fetchNotifications(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/seguimiento/notificaciones'),
      headers: _authHeaders(accessToken),
    );

    _throwIfError(
      response,
      fallback: 'No fue posible cargar las notificaciones',
    );

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['notificaciones'] as List<dynamic>? ??
                decoded['data'] as List<dynamic>? ??
                decoded['items'] as List<dynamic>? ??
                const []
            : const [];

    final notifications = rawList
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationModel.fromJson)
        .toList();

    notifications.sort((a, b) {
      final aDate = a.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return notifications;
  }

  Future<AppNotificationModel> fetchNotificationDetail({
    required int idNotificacion,
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${AppConfig.baseUrl}/seguimiento/notificaciones/$idNotificacion',
      ),
      headers: _authHeaders(accessToken),
    );

    _throwIfError(
      response,
      fallback: 'No fue posible cargar la notificación',
    );

    return AppNotificationModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> markNotificationAsRead({
    required int idNotificacion,
    required String accessToken,
  }) async {
    final response = await _client.patch(
      Uri.parse(
        '${AppConfig.baseUrl}/seguimiento/notificaciones/$idNotificacion/leer',
      ),
      headers: _authHeaders(accessToken),
    );

    _throwIfError(
      response,
      fallback: 'No fue posible marcar la notificación como leída',
    );
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  void _throwIfError(http.Response response, {required String fallback}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401) {
      throw const NotificationException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    throw NotificationException(
      _messageFromBody(response.body) ?? fallback,
      statusCode: response.statusCode,
    );
  }

  String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['detail'] ?? decoded['mensaje'] ?? decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

class NotificationException implements Exception {
  final String message;
  final int? statusCode;

  const NotificationException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
