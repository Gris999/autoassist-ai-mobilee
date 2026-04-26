class PaymentChargeItem {
  final String concepto;
  final String descripcion;
  final double monto;
  final String moneda;

  const PaymentChargeItem({
    required this.concepto,
    required this.descripcion,
    required this.monto,
    required this.moneda,
  });

  factory PaymentChargeItem.fromJson(Map<String, dynamic> json) {
    return PaymentChargeItem(
      concepto: json['concepto'] as String? ??
          json['nombre'] as String? ??
          json['descripcion'] as String? ??
          'Concepto',
      descripcion: json['descripcion'] as String? ?? '',
      monto: _toDouble(json['monto'] ?? json['subtotal'] ?? json['importe']),
      moneda: json['moneda'] as String? ?? '',
    );
  }
}

class PaymentDetailModel {
  final int idIncidente;
  final String titulo;
  final String estadoServicioActual;
  final int idEstadoServicioActual;
  final String tipoIncidente;
  final String nombreTaller;
  final int idTaller;
  final String moneda;
  final double montoTotal;
  final bool habilitadoParaPago;
  final String mensaje;
  final List<String> metodosPagoDisponibles;
  final List<PaymentChargeItem> detallesCobro;
  final Map<String, dynamic>? pagoExistente;
  final String estadoPago;
  final String referenciaTransaccion;

  const PaymentDetailModel({
    required this.idIncidente,
    required this.titulo,
    required this.estadoServicioActual,
    required this.idEstadoServicioActual,
    required this.tipoIncidente,
    required this.nombreTaller,
    required this.idTaller,
    required this.moneda,
    required this.montoTotal,
    required this.habilitadoParaPago,
    required this.mensaje,
    required this.metodosPagoDisponibles,
    required this.detallesCobro,
    required this.pagoExistente,
    required this.estadoPago,
    required this.referenciaTransaccion,
  });

  factory PaymentDetailModel.fromJson(Map<String, dynamic> json) {
    final pagoExistente = json['pago_existente'];
    final details = _listFrom(json['detalles_cobro'] ?? json['detalles']);

    return PaymentDetailModel(
      idIncidente: _toInt(json['id_incidente']),
      titulo: json['titulo'] as String? ??
          json['titulo_incidente'] as String? ??
          'Servicio de auxilio',
      estadoServicioActual:
          json['estado_servicio_actual'] as String? ?? 'Estado del servicio',
      idEstadoServicioActual: _toInt(json['id_estado_servicio_actual']),
      tipoIncidente: json['tipo_incidente'] as String? ?? '',
      nombreTaller: json['nombre_taller'] as String? ??
          json['taller'] as String? ??
          'Taller pendiente',
      idTaller: _toInt(json['id_taller']),
      moneda: json['moneda'] as String? ?? 'USD',
      montoTotal: _toDouble(json['monto_total']),
      habilitadoParaPago: json['habilitado_para_pago'] as bool? ?? false,
      mensaje: json['mensaje'] as String? ?? '',
      metodosPagoDisponibles:
          _listFrom(json['metodos_pago_disponibles']).map((e) => e.toString()).toList(),
      detallesCobro: details
          .whereType<Map<String, dynamic>>()
          .map(PaymentChargeItem.fromJson)
          .toList(),
      pagoExistente:
          pagoExistente is Map<String, dynamic> ? pagoExistente : null,
      estadoPago: json['estado_pago'] as String? ??
          (pagoExistente is Map<String, dynamic>
              ? pagoExistente['estado_pago'] as String? ?? ''
              : ''),
      referenciaTransaccion: json['referencia_transaccion'] as String? ??
          (pagoExistente is Map<String, dynamic>
              ? pagoExistente['referencia_transaccion'] as String? ?? ''
              : ''),
    );
  }
}

class PaymentIntentModel {
  final int idPagoServicio;
  final int idIncidente;
  final double montoTotal;
  final String moneda;
  final String estadoPago;
  final String clientSecret;
  final String paymentIntentId;
  final String publishableKey;
  final String metodoPago;
  final String mensaje;

  const PaymentIntentModel({
    required this.idPagoServicio,
    required this.idIncidente,
    required this.montoTotal,
    required this.moneda,
    required this.estadoPago,
    required this.clientSecret,
    required this.paymentIntentId,
    required this.publishableKey,
    required this.metodoPago,
    required this.mensaje,
  });

  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
    return PaymentIntentModel(
      idPagoServicio: _toInt(json['id_pago_servicio']),
      idIncidente: _toInt(json['id_incidente']),
      montoTotal: _toDouble(json['monto_total']),
      moneda: json['moneda'] as String? ?? 'USD',
      estadoPago: json['estado_pago'] as String? ?? '',
      clientSecret: json['client_secret'] as String? ?? '',
      paymentIntentId: json['payment_intent_id'] as String? ?? '',
      publishableKey: json['publishable_key'] as String? ?? '',
      metodoPago: json['metodo_pago'] as String? ?? 'STRIPE_CARD',
      mensaje: json['mensaje'] as String? ?? '',
    );
  }
}

class PaymentReceiptModel {
  final int idPagoServicio;
  final int idIncidente;
  final String tituloIncidente;
  final String nombreTaller;
  final String metodoPago;
  final String estadoPago;
  final double montoTotal;
  final String moneda;
  final DateTime? fechaPago;
  final String referenciaTransaccion;
  final String receiptUrl;
  final List<PaymentChargeItem> detalles;
  final double comisionPlataforma;

  const PaymentReceiptModel({
    required this.idPagoServicio,
    required this.idIncidente,
    required this.tituloIncidente,
    required this.nombreTaller,
    required this.metodoPago,
    required this.estadoPago,
    required this.montoTotal,
    required this.moneda,
    required this.fechaPago,
    required this.referenciaTransaccion,
    required this.receiptUrl,
    required this.detalles,
    required this.comisionPlataforma,
  });

  factory PaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return PaymentReceiptModel(
      idPagoServicio: _toInt(json['id_pago_servicio']),
      idIncidente: _toInt(json['id_incidente']),
      tituloIncidente: json['titulo_incidente'] as String? ??
          json['titulo'] as String? ??
          'Servicio de auxilio',
      nombreTaller: json['nombre_taller'] as String? ??
          json['taller'] as String? ??
          'Taller',
      metodoPago: json['metodo_pago'] as String? ?? '',
      estadoPago: json['estado_pago'] as String? ?? '',
      montoTotal: _toDouble(json['monto_total']),
      moneda: json['moneda'] as String? ?? 'USD',
      fechaPago: DateTime.tryParse(json['fecha_pago'] as String? ?? ''),
      referenciaTransaccion:
          json['referencia_transaccion'] as String? ?? '',
      receiptUrl: json['receipt_url'] as String? ?? '',
      detalles: _listFrom(json['detalles'])
          .whereType<Map<String, dynamic>>()
          .map(PaymentChargeItem.fromJson)
          .toList(),
      comisionPlataforma: _toDouble(json['comision_plataforma']),
    );
  }
}

class DemoPaymentConfirmationModel {
  final int idPagoServicio;
  final int idIncidente;
  final String estadoPago;
  final String referenciaTransaccion;
  final String mensaje;

  const DemoPaymentConfirmationModel({
    required this.idPagoServicio,
    required this.idIncidente,
    required this.estadoPago,
    required this.referenciaTransaccion,
    required this.mensaje,
  });

  factory DemoPaymentConfirmationModel.fromJson(Map<String, dynamic> json) {
    return DemoPaymentConfirmationModel(
      idPagoServicio: _toInt(json['id_pago_servicio']),
      idIncidente: _toInt(json['id_incidente']),
      estadoPago: json['estado_pago'] as String? ?? '',
      referenciaTransaccion: json['referencia_transaccion'] as String? ?? '',
      mensaje: json['mensaje'] as String? ?? '',
    );
  }
}

List<dynamic> _listFrom(Object? value) {
  if (value is List<dynamic>) return value;
  return const [];
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
