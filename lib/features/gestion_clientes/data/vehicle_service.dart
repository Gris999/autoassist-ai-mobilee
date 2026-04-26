import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'vehicle_models.dart';

class VehicleService {
  final http.Client _client;

  VehicleService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ClientVehicle>> fetchClientVehicles(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/clientes/vehiculos'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 401) {
      throw const VehicleException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const VehicleException(
        'No tienes permiso para consultar vehículos.',
        statusCode: 403,
      );
    }

    if (response.statusCode != 200) {
      throw const VehicleException('No fue posible cargar tus vehículos');
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['vehiculos'] as List<dynamic>? ??
                decoded['data'] as List<dynamic>? ??
                decoded['items'] as List<dynamic>? ??
                const []
            : const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ClientVehicle.fromJson)
        .where((vehicle) => vehicle.idVehiculo > 0)
        .toList();
  }

  Future<List<VehicleType>> fetchVehicleTypes(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/clientes/tipos-vehiculo'),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode == 401) {
      throw const VehicleException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const VehicleException(
        'No tienes permiso para registrar vehículos.',
        statusCode: 403,
      );
    }

    if (response.statusCode != 200) {
      throw const VehicleException('No fue posible cargar tipos de vehículo');
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
        .map(VehicleType.fromJson)
        .where((type) => type.idTipoVehiculo > 0)
        .toList();
  }

  Future<VehicleRegistration> registerVehicle({
    required String accessToken,
    required int idTipoVehiculo,
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
    required String descripcionReferencia,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/clientes/vehiculos'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'id_tipo_vehiculo': idTipoVehiculo,
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'color': color,
        'descripcion_referencia': descripcionReferencia,
      }),
    );

    if (response.statusCode == 401) {
      throw const VehicleException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const VehicleException(
        'No tienes permiso para registrar vehículos.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 400) {
      throw const VehicleException(
        'Verifica los datos ingresados',
        statusCode: 400,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const VehicleException('No fue posible registrar el vehículo');
    }

    return VehicleRegistration.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }
}

class VehicleException implements Exception {
  final String message;
  final int? statusCode;

  const VehicleException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
