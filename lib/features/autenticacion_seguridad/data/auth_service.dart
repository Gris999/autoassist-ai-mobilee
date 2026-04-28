import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/auth_user.dart';

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<RegisterClientResponse> registerClient({
    required String nombres,
    required String apellidos,
    required String celular,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register/cliente'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombres': nombres,
        'apellidos': apellidos,
        'celular': celular,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(_registerErrorMessage(response));
    }

    return RegisterClientResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 401) {
      throw const AuthException('Correo o contraseña incorrectos');
    }

    if (response.statusCode != 200) {
      throw const AuthException('No se pudo iniciar sesión');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['access_token']?.toString();

    if (token == null || token.isEmpty) {
      throw const AuthException('El backend no devolvió access_token');
    }

    return token;
  }

  Future<AuthUser> me(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401) {
      throw const AuthException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      throw const AuthException(
        'No se pudo recuperar el usuario autenticado',
      );
    }

    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> logout(String accessToken) async {
    if (accessToken.trim().isEmpty) return;

    await _client.post(
      Uri.parse('${AppConfig.baseUrl}/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
  }

  String _registerErrorMessage(http.Response response) {
    if (response.statusCode == 400) {
      return _messageFromBody(response.body) ?? 'Verifica los datos ingresados';
    }

    return _friendlyRegisterError(response.body);
  }

  String _friendlyRegisterError(String responseBody) {
    final lowerBody = responseBody.toLowerCase();

    if (lowerBody.contains('email') ||
        lowerBody.contains('correo') ||
        lowerBody.contains('already') ||
        lowerBody.contains('registr')) {
      return 'Este correo ya está registrado';
    }

    if (lowerBody.contains('valid') || lowerBody.contains('dato')) {
      return 'Verifica los datos ingresados';
    }

    return 'No fue posible completar el registro';
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
        if (message is List && message.isNotEmpty) {
          return message.map((item) => item.toString()).join('\n');
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RegisterClientResponse {
  final RegisteredClient usuario;
  final String rol;

  const RegisterClientResponse({
    required this.usuario,
    required this.rol,
  });

  factory RegisterClientResponse.fromJson(Map<String, dynamic> json) {
    return RegisterClientResponse(
      usuario: RegisteredClient.fromJson(
        json['usuario'] as Map<String, dynamic>? ?? const {},
      ),
      rol: json['rol']?.toString().toUpperCase() ?? 'CLIENTE',
    );
  }
}

class RegisteredClient {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String celular;
  final String email;
  final bool estado;
  final DateTime? fechaRegistro;

  const RegisteredClient({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.celular,
    required this.email,
    required this.estado,
    required this.fechaRegistro,
  });

  factory RegisteredClient.fromJson(Map<String, dynamic> json) {
    return RegisteredClient(
      idUsuario: json['id_usuario'] as int? ?? 0,
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      celular: json['celular'] as String? ?? '',
      email: json['email'] as String? ?? '',
      estado: json['estado'] as bool? ?? false,
      fechaRegistro: DateTime.tryParse(
        json['fecha_registro'] as String? ?? '',
      ),
    );
  }
}
