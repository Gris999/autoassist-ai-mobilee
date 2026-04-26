import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'payment_models.dart';

class PaymentService {
  final http.Client _client;

  PaymentService({http.Client? client}) : _client = client ?? http.Client();

  Future<PaymentDetailModel> fetchPaymentDetail({
    required int idIncidente,
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/seguimiento/pagos/incidentes/$idIncidente'),
      headers: _authHeaders(accessToken),
    );

    _throwIfError(response, fallback: 'No fue posible cargar el detalle del cobro');

    return PaymentDetailModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PaymentIntentModel> createPaymentIntent({
    required int idIncidente,
    required String accessToken,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.baseUrl}/seguimiento/pagos/incidentes/$idIncidente/intencion',
      ),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'metodo_pago': 'STRIPE_CARD'}),
    );
    debugPrint('CU10 intencion response=${response.body}');

    _throwIfError(response, fallback: 'No fue posible generar el pago seguro');

    return PaymentIntentModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<DemoPaymentConfirmationModel> confirmDemoPayment({
    required int idIncidente,
    required String accessToken,
    String? referenciaDemo,
  }) async {
    final body = {
      'metodo_pago': 'DEMO_CARD',
      if (referenciaDemo != null && referenciaDemo.isNotEmpty)
        'referencia_demo': referenciaDemo,
    };

    final response = await _client.post(
      Uri.parse(
        '${AppConfig.baseUrl}/seguimiento/pagos/incidentes/$idIncidente/confirmar-demo',
      ),
      headers: _authHeaders(accessToken),
      body: jsonEncode(body),
    );
    debugPrint('CU10 confirmar-demo response=${response.body}');

    _throwIfError(response, fallback: 'No fue posible registrar el pago');

    return DemoPaymentConfirmationModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PaymentReceiptModel> fetchReceipt({
    required int idPagoServicio,
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${AppConfig.baseUrl}/seguimiento/pagos/$idPagoServicio/comprobante',
      ),
      headers: _authHeaders(accessToken),
    );
    debugPrint('CU10 comprobante response=${response.body}');

    _throwIfError(response, fallback: 'No fue posible obtener el comprobante');

    return PaymentReceiptModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
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
      throw const PaymentException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw const PaymentException(
        'No tienes permiso para consultar este pago.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 400) {
      throw PaymentException(
        _messageFromBody(response.body) ?? 'Revisa el método de pago.',
        statusCode: 400,
      );
    }

    throw PaymentException(
      _messageFromBody(response.body) ?? fallback,
      statusCode: response.statusCode,
    );
  }

  String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] ?? decoded['mensaje'] ?? decoded['message'];
        return detail?.toString();
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

class PaymentException implements Exception {
  final String message;
  final int? statusCode;

  const PaymentException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
