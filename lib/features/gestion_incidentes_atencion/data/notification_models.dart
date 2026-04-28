class AppNotificationModel {
  final int idNotificacion;
  final int? idIncidente;
  final String titulo;
  final String mensaje;
  final String tipoNotificacion;
  final bool leido;
  final DateTime? fechaEnvio;

  const AppNotificationModel({
    required this.idNotificacion,
    required this.idIncidente,
    required this.titulo,
    required this.mensaje,
    required this.tipoNotificacion,
    required this.leido,
    required this.fechaEnvio,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      idNotificacion: _toInt(json['id_notificacion']),
      idIncidente: _nullableInt(json['id_incidente']),
      titulo: json['titulo'] as String? ?? 'Notificación',
      mensaje: json['mensaje'] as String? ?? '',
      tipoNotificacion:
          json['tipo_notificacion']?.toString().toUpperCase() ?? '',
      leido: json['leido'] as bool? ?? false,
      fechaEnvio: DateTime.tryParse(json['fecha_envio'] as String? ?? ''),
    );
  }

  AppNotificationModel copyWith({bool? leido}) {
    return AppNotificationModel(
      idNotificacion: idNotificacion,
      idIncidente: idIncidente,
      titulo: titulo,
      mensaje: mensaje,
      tipoNotificacion: tipoNotificacion,
      leido: leido ?? this.leido,
      fechaEnvio: fechaEnvio,
    );
  }

  bool get opensAssignment {
    return switch (tipoNotificacion) {
      'TALLER_ACEPTO' ||
      'ASIGNACION_TECNICO' ||
      'TECNICO_ASIGNADO' ||
      'UNIDAD_MOVIL_ASIGNADA' ||
      'UNIDAD_ASIGNADA' ||
      'ASIGNACION_COMPLETA' =>
        true,
      _ => false,
    };
  }
}

int _toInt(Object? value) {
  return _nullableInt(value) ?? 0;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
