import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'incident_models.dart';

class IncidentService {
  final http.Client _client;

  IncidentService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ClientIncident>> fetchMyIncidents(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/incidentes/mis'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401) {
      throw const IncidentException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const IncidentException(
        'No tienes permiso para consultar estos servicios.',
        statusCode: 403,
      );
    }

    if (response.statusCode != 200) {
      debugPrint(
        'GET /incidentes/mis status=${response.statusCode} '
        'body=${response.body}',
      );
      throw const IncidentException(
        'No fue posible cargar el estado de tus servicios',
      );
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['incidentes'] as List<dynamic>? ??
                decoded['data'] as List<dynamic>? ??
                decoded['items'] as List<dynamic>? ??
                const []
            : const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ClientIncident.fromJson)
        .toList();
  }

  Future<List<IncidentType>> fetchIncidentTypes(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/incidentes/tipos-incidente'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401) {
      throw const IncidentException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const IncidentException(
        'No tienes permiso para consultar tipos de incidente.',
        statusCode: 403,
      );
    }

    if (response.statusCode != 200) {
      debugPrint(
        'GET /incidentes/tipos-incidente '
        'status=${response.statusCode} body=${response.body}',
      );
      throw const IncidentException(
        'No fue posible cargar tipos de incidente',
      );
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['tipos'] as List<dynamic>? ??
                decoded['data'] as List<dynamic>? ??
                decoded['items'] as List<dynamic>? ??
                const []
            : const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(IncidentType.fromJson)
        .where((type) => type.idTipoIncidente > 0 && type.estado)
        .toList();
  }

  Future<Incident> createIncident({
    required String accessToken,
    required int idVehiculo,
    required int idTipoIncidente,
    required String titulo,
    required String descripcionTexto,
    required String direccionReferencia,
    required double latitud,
    required double longitud,
  }) async {
    final requestBody = {
      'id_vehiculo': idVehiculo,
      'id_tipo_incidente': idTipoIncidente,
      'titulo': titulo,
      'descripcion_texto': descripcionTexto,
      'direccion_referencia': direccionReferencia,
      'latitud': latitud,
      'longitud': longitud,
    };

    debugPrint('POST /incidentes body=${jsonEncode(requestBody)}');

    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/incidentes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint(
      'POST /incidentes status=${response.statusCode} body=${response.body}',
    );

    if (response.statusCode == 401) {
      throw const IncidentException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const IncidentException(
        'No tienes permiso para reportar incidentes.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      throw const IncidentException(
        'Verifica los datos ingresados',
        statusCode: 400,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const IncidentException('No fue posible reportar el incidente');
    }

    return Incident.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class IncidentException implements Exception {
  final String message;
  final int? statusCode;

  const IncidentException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
