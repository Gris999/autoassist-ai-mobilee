import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'incident_assignment_models.dart';

class IncidentAssignmentService {
  final http.Client _client;

  IncidentAssignmentService({http.Client? client})
      : _client = client ?? http.Client();

  Future<IncidentAssignmentModel> fetchIncidentAssignment({
    required int idIncidente,
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${AppConfig.baseUrl}/seguimiento/cliente/incidentes/$idIncidente/asignacion',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 404) {
      return IncidentAssignmentModel.empty(
        idIncidente: idIncidente,
        mensaje: _messageFromBody(response.body) ??
            'Todavía no hay asignación disponible.',
      );
    }

    _throwIfError(response);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final asignacion = decoded['asignacion'];
    final data = decoded['data'];
    final payload = asignacion is Map<String, dynamic>
        ? asignacion
        : data is Map<String, dynamic>
            ? data
            : decoded;

    return IncidentAssignmentModel.fromJson(payload);
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401) {
      throw const IncidentAssignmentException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    throw IncidentAssignmentException(
      _messageFromBody(response.body) ??
          'No fue posible cargar la asignación del auxilio',
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

class IncidentAssignmentException implements Exception {
  final String message;
  final int? statusCode;

  const IncidentAssignmentException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
