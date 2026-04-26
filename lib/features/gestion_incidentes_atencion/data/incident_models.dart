class Incident {
  final int idIncidente;
  final int idVehiculo;
  final String titulo;
  final String descripcionTexto;
  final String direccionReferencia;
  final double latitud;
  final double longitud;

  const Incident({
    required this.idIncidente,
    required this.idVehiculo,
    required this.titulo,
    required this.descripcionTexto,
    required this.direccionReferencia,
    required this.latitud,
    required this.longitud,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      idIncidente: json['id_incidente'] as int? ?? json['id'] as int? ?? 0,
      idVehiculo: json['id_vehiculo'] as int? ?? 0,
      titulo: json['titulo'] as String? ?? '',
      descripcionTexto: json['descripcion_texto'] as String? ?? '',
      direccionReferencia: json['direccion_referencia'] as String? ?? '',
      latitud: _toDouble(json['latitud']),
      longitud: _toDouble(json['longitud']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class IncidentType {
  final int idTipoIncidente;
  final String nombre;
  final String descripcion;
  final bool estado;

  const IncidentType({
    required this.idTipoIncidente,
    required this.nombre,
    required this.descripcion,
    required this.estado,
  });

  factory IncidentType.fromJson(Map<String, dynamic> json) {
    return IncidentType(
      idTipoIncidente: json['id_tipo_incidente'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      estado: json['estado'] as bool? ?? true,
    );
  }

  String get displayName {
    final normalized = nombre.replaceAll('_', ' ').toLowerCase();
    return normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class ClientIncident {
  final int idIncidente;
  final int idCliente;
  final int idVehiculo;
  final int idTipoIncidente;
  final int idPrioridad;
  final int idEstadoServicioActual;
  final String titulo;
  final String descripcionTexto;
  final String direccionReferencia;
  final double latitud;
  final double longitud;
  final DateTime? fechaReporte;
  final String clasificacionIa;
  final double confianzaClasificacion;
  final String resumenIa;
  final bool requiereMasInfo;

  const ClientIncident({
    required this.idIncidente,
    required this.idCliente,
    required this.idVehiculo,
    required this.idTipoIncidente,
    required this.idPrioridad,
    required this.idEstadoServicioActual,
    required this.titulo,
    required this.descripcionTexto,
    required this.direccionReferencia,
    required this.latitud,
    required this.longitud,
    required this.fechaReporte,
    required this.clasificacionIa,
    required this.confianzaClasificacion,
    required this.resumenIa,
    required this.requiereMasInfo,
  });

  factory ClientIncident.fromJson(Map<String, dynamic> json) {
    return ClientIncident(
      idIncidente: json['id_incidente'] as int? ?? 0,
      idCliente: json['id_cliente'] as int? ?? 0,
      idVehiculo: json['id_vehiculo'] as int? ?? 0,
      idTipoIncidente: json['id_tipo_incidente'] as int? ?? 0,
      idPrioridad: json['id_prioridad'] as int? ?? 0,
      idEstadoServicioActual:
          json['id_estado_servicio_actual'] as int? ?? 0,
      titulo: json['titulo'] as String? ?? '',
      descripcionTexto: json['descripcion_texto'] as String? ?? '',
      direccionReferencia: json['direccion_referencia'] as String? ?? '',
      latitud: Incident._toDouble(json['latitud']),
      longitud: Incident._toDouble(json['longitud']),
      fechaReporte: DateTime.tryParse(json['fecha_reporte'] as String? ?? ''),
      clasificacionIa: json['clasificacion_ia'] as String? ?? '',
      confianzaClasificacion:
          Incident._toDouble(json['confianza_clasificacion']),
      resumenIa: json['resumen_ia'] as String? ?? '',
      requiereMasInfo: json['requiere_mas_info'] as bool? ?? false,
    );
  }

  String get shortDescription {
    if (descripcionTexto.length <= 92) return descripcionTexto;
    return '${descripcionTexto.substring(0, 89)}...';
  }

  String get stateLabel {
    return _stateNames[idEstadoServicioActual] ??
        'Estado #$idEstadoServicioActual';
  }

  String get priorityLabel {
    return idPrioridad == 0 ? 'Sin prioridad' : 'Prioridad #$idPrioridad';
  }

  static const Map<int, String> _stateNames = {
    1: 'Reportado',
    2: 'Pendiente',
    3: 'Asignado',
    4: 'En camino',
    5: 'En atención',
    6: 'Finalizado',
    7: 'Cancelado',
  };
}
