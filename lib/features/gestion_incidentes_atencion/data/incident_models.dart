class Incident {
  final int idIncidente;
  final int idVehiculo;
  final String titulo;
  final String descripcionTexto;
  final String direccionReferencia;
  final double latitud;
  final double longitud;
  final int idEstadoServicioActual;
  final String estadoServicioActual;
  final int idPrioridad;
  final DateTime? fechaReporte;
  final String clasificacionIa;
  final double confianzaClasificacion;
  final String resumenIa;
  final bool requiereMasInfo;

  const Incident({
    required this.idIncidente,
    required this.idVehiculo,
    required this.titulo,
    required this.descripcionTexto,
    required this.direccionReferencia,
    required this.latitud,
    required this.longitud,
    required this.idEstadoServicioActual,
    required this.estadoServicioActual,
    required this.idPrioridad,
    required this.fechaReporte,
    required this.clasificacionIa,
    required this.confianzaClasificacion,
    required this.resumenIa,
    required this.requiereMasInfo,
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
      idEstadoServicioActual:
          json['id_estado_servicio_actual'] as int? ?? 0,
      estadoServicioActual:
          json['estado_servicio_actual'] as String? ??
          json['estado'] as String? ??
          '',
      idPrioridad: json['id_prioridad'] as int? ?? 0,
      fechaReporte: DateTime.tryParse(json['fecha_reporte'] as String? ?? ''),
      clasificacionIa: json['clasificacion_ia'] as String? ?? '',
      confianzaClasificacion: _toDouble(json['confianza_clasificacion']),
      resumenIa: json['resumen_ia'] as String? ?? '',
      requiereMasInfo: json['requiere_mas_info'] as bool? ?? false,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class IncidentEvidenceInput {
  final String tipoEvidencia;
  final String archivoUrl;
  final String textoExtraido;
  final String descripcion;

  const IncidentEvidenceInput({
    required this.tipoEvidencia,
    required this.archivoUrl,
    this.textoExtraido = '',
    this.descripcion = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'tipo_evidencia': tipoEvidencia,
      'archivo_url': archivoUrl,
      if (textoExtraido.trim().isNotEmpty)
        'texto_extraido': textoExtraido.trim(),
      if (descripcion.trim().isNotEmpty) 'descripcion': descripcion.trim(),
    };
  }
}

class UploadedIncidentEvidence {
  final String tipoEvidencia;
  final String archivoUrl;
  final String nombreArchivo;
  final int tamanoBytes;
  final String contentType;

  const UploadedIncidentEvidence({
    required this.tipoEvidencia,
    required this.archivoUrl,
    required this.nombreArchivo,
    required this.tamanoBytes,
    required this.contentType,
  });

  factory UploadedIncidentEvidence.fromJson(Map<String, dynamic> json) {
    return UploadedIncidentEvidence(
      tipoEvidencia: json['tipo_evidencia'] as String? ?? 'AUDIO',
      archivoUrl: json['archivo_url'] as String? ?? '',
      nombreArchivo: json['nombre_archivo'] as String? ?? '',
      tamanoBytes: json['tamano_bytes'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }
}

class TranscribedAudioEvidence {
  final String archivoUrl;
  final String textoExtraido;
  final String mensaje;

  const TranscribedAudioEvidence({
    required this.archivoUrl,
    required this.textoExtraido,
    required this.mensaje,
  });

  factory TranscribedAudioEvidence.fromJson(Map<String, dynamic> json) {
    return TranscribedAudioEvidence(
      archivoUrl: json['archivo_url'] as String? ?? '',
      textoExtraido: json['texto_extraido'] as String? ?? '',
      mensaje: json['mensaje'] as String? ?? '',
    );
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
  final String estadoServicioActual;
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
    required this.estadoServicioActual,
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
      estadoServicioActual:
          json['estado_servicio_actual'] as String? ??
          json['estado'] as String? ??
          '',
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
    return _stateLabels[normalizedState] ??
        _stateNames[idEstadoServicioActual] ??
        'Estado #$idEstadoServicioActual';
  }

  String get normalizedState {
    final raw = estadoServicioActual.trim();
    if (raw.isNotEmpty) return raw.toUpperCase();
    return _stateKeys[idEstadoServicioActual] ?? '';
  }

  int get progressStep {
    return _stateProgress[normalizedState] ?? idEstadoServicioActual;
  }

  bool get isCancelled => normalizedState == 'CANCELADO';

  String get stateDescription {
    return _stateDescriptions[normalizedState] ??
        'Consulta el avance actualizado de tu servicio.';
  }

  String get priorityLabel {
    return idPrioridad == 0 ? 'Sin prioridad' : 'Prioridad #$idPrioridad';
  }

  static const Map<int, String> _stateNames = {
    1: 'Reportado',
    2: 'Buscando taller',
    3: 'Asignado',
    4: 'En camino',
    5: 'En atención',
    6: 'Finalizado',
    7: 'Cancelado',
  };

  static const Map<int, String> _stateKeys = {
    1: 'REPORTADO',
    2: 'BUSCANDO_TALLER',
    3: 'ASIGNADO',
    4: 'EN_CAMINO',
    5: 'EN_ATENCION',
    6: 'FINALIZADO',
    7: 'CANCELADO',
  };

  static const Map<String, int> _stateProgress = {
    'REPORTADO': 1,
    'BUSCANDO_TALLER': 2,
    'ASIGNADO': 3,
    'EN_CAMINO': 4,
    'EN_ATENCION': 5,
    'FINALIZADO': 6,
    'CANCELADO': 7,
  };

  static const Map<String, String> _stateLabels = {
    'REPORTADO': 'Reportado',
    'BUSCANDO_TALLER': 'Buscando taller',
    'ASIGNADO': 'Asignado',
    'EN_CAMINO': 'En camino',
    'EN_ATENCION': 'En atención',
    'FINALIZADO': 'Finalizado',
    'CANCELADO': 'Cancelado',
  };

  static const Map<String, String> _stateDescriptions = {
    'REPORTADO': 'Incidente recibido. Estamos validando la información enviada.',
    'BUSCANDO_TALLER':
        'Estamos contactando talleres compatibles con tu solicitud.',
    'ASIGNADO': 'Un taller aceptó la solicitud de auxilio.',
    'EN_CAMINO': 'Tu auxilio está en camino.',
    'EN_ATENCION': 'Tu incidente está siendo atendido.',
    'FINALIZADO': 'Servicio finalizado.',
    'CANCELADO': 'Servicio cancelado.',
  };
}
