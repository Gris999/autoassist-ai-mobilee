class IncidentAssignmentModel {
  final int idIncidente;
  final bool asignacionDefinida;
  final String titulo;
  final String tipoIncidente;
  final String estadoServicioActual;
  final String? estadoAsignacion;
  final int? tiempoEstimadoMin;
  final String? mensaje;
  final TallerAsignadoModel? taller;
  final TecnicoAsignadoModel? tecnico;
  final UnidadMovilAsignadaModel? unidadMovil;
  final String? placaVehiculo;
  final String? marcaVehiculo;
  final String? modeloVehiculo;

  const IncidentAssignmentModel({
    required this.idIncidente,
    required this.asignacionDefinida,
    required this.titulo,
    required this.tipoIncidente,
    required this.estadoServicioActual,
    required this.estadoAsignacion,
    required this.tiempoEstimadoMin,
    required this.mensaje,
    required this.taller,
    required this.tecnico,
    required this.unidadMovil,
    required this.placaVehiculo,
    required this.marcaVehiculo,
    required this.modeloVehiculo,
  });

  factory IncidentAssignmentModel.empty({
    required int idIncidente,
    String? mensaje,
  }) {
    return IncidentAssignmentModel(
      idIncidente: idIncidente,
      asignacionDefinida: false,
      titulo: 'Servicio de auxilio',
      tipoIncidente: '',
      estadoServicioActual: 'BUSCANDO_TALLER',
      estadoAsignacion: null,
      tiempoEstimadoMin: null,
      mensaje: mensaje ?? 'Todavía no hay asignación disponible.',
      taller: null,
      tecnico: null,
      unidadMovil: null,
      placaVehiculo: null,
      marcaVehiculo: null,
      modeloVehiculo: null,
    );
  }

  factory IncidentAssignmentModel.fromJson(Map<String, dynamic> json) {
    final taller = _mapFrom(json['taller'] ?? json['taller_asignado']) ??
        _flatTallerFrom(json);
    final tecnico = _mapFrom(json['tecnico'] ?? json['tecnico_asignado']) ??
        _flatTecnicoFrom(json);
    final unidad = _mapFrom(json['unidad_movil'] ?? json['unidad_asignada']) ??
        _flatUnidadFrom(json);
    final vehiculo = _mapFrom(json['vehiculo'] ?? json['vehiculo_cliente']);
    final hasAnyAssignment = taller != null || tecnico != null || unidad != null;

    return IncidentAssignmentModel(
      idIncidente: _toInt(json['id_incidente'] ?? json['incidente_id']),
      asignacionDefinida:
          json['asignacion_definida'] as bool? ?? hasAnyAssignment,
      titulo: json['titulo'] as String? ??
          json['titulo_incidente'] as String? ??
          'Servicio de auxilio',
      tipoIncidente: json['tipo_incidente'] as String? ?? '',
      estadoServicioActual: json['estado_servicio_actual'] as String? ??
          json['estado_servicio'] as String? ??
          '',
      estadoAsignacion: json['estado_asignacion'] as String?,
      tiempoEstimadoMin:
          _nullableInt(json['tiempo_estimado_min'] ?? json['eta_min']),
      mensaje: json['mensaje'] as String? ?? json['message'] as String?,
      taller: taller == null ? null : TallerAsignadoModel.fromJson(taller),
      tecnico:
          tecnico == null ? null : TecnicoAsignadoModel.fromJson(tecnico),
      unidadMovil:
          unidad == null ? null : UnidadMovilAsignadaModel.fromJson(unidad),
      placaVehiculo:
          json['placa_vehiculo'] as String? ?? vehiculo?['placa'] as String?,
      marcaVehiculo:
          json['marca_vehiculo'] as String? ?? vehiculo?['marca'] as String?,
      modeloVehiculo:
          json['modelo_vehiculo'] as String? ?? vehiculo?['modelo'] as String?,
    );
  }

  bool get hasTaller => taller != null;
  bool get hasTecnico => tecnico != null;
  bool get hasUnidadMovil => unidadMovil != null;
  bool get isComplete => hasTaller && hasTecnico && hasUnidadMovil;

  String get friendlyState {
    final normalized = estadoServicioActual.trim().toUpperCase();
    return switch (normalized) {
      'REPORTADO' => 'Reportado',
      'BUSCANDO_TALLER' => 'Buscando taller',
      'ASIGNADO' => 'Asignado',
      'EN_CAMINO' => 'En camino',
      'EN_ATENCION' => 'En atención',
      'FINALIZADO' => 'Finalizado',
      'CANCELADO' => 'Cancelado',
      _ => estadoServicioActual.isEmpty
          ? 'Estado pendiente'
          : estadoServicioActual,
    };
  }

  String get assignmentSummary {
    if (!hasTaller) {
      return mensaje ?? 'Aún no hay un taller asignado.';
    }
    if (!hasTecnico || !hasUnidadMovil) {
      return mensaje ??
          'Taller aceptó la solicitud. Pendiente de asignación de técnico y unidad.';
    }
    return mensaje ?? 'Asignación completa para la atención del auxilio.';
  }
}

class TallerAsignadoModel {
  final int? idTaller;
  final String nombreTaller;
  final String? direccionTaller;
  final String? telefonoContacto;

  const TallerAsignadoModel({
    required this.idTaller,
    required this.nombreTaller,
    required this.direccionTaller,
    required this.telefonoContacto,
  });

  factory TallerAsignadoModel.fromJson(Map<String, dynamic> json) {
    return TallerAsignadoModel(
      idTaller: _nullableInt(json['id_taller'] ?? json['id']),
      nombreTaller: json['nombre_taller'] as String? ??
          json['nombre'] as String? ??
          json['razon_social'] as String? ??
          'Taller asignado',
      direccionTaller:
          json['direccion_taller'] as String? ?? json['direccion'] as String?,
      telefonoContacto: json['telefono_contacto'] as String? ??
          json['telefono'] as String? ??
          json['celular'] as String?,
    );
  }
}

class TecnicoAsignadoModel {
  final int? idTecnico;
  final String nombreTecnico;
  final String? telefonoContacto;

  const TecnicoAsignadoModel({
    required this.idTecnico,
    required this.nombreTecnico,
    required this.telefonoContacto,
  });

  factory TecnicoAsignadoModel.fromJson(Map<String, dynamic> json) {
    final nombres = json['nombres'] as String? ?? '';
    final apellidos = json['apellidos'] as String? ?? '';
    final fullName = '$nombres $apellidos'.trim();

    return TecnicoAsignadoModel(
      idTecnico: _nullableInt(json['id_tecnico'] ?? json['id']),
      nombreTecnico: json['nombre_tecnico'] as String? ??
          json['nombre'] as String? ??
          (fullName.isEmpty ? 'Técnico asignado' : fullName),
      telefonoContacto: json['telefono_contacto'] as String? ??
          json['telefono'] as String? ??
          json['celular'] as String?,
    );
  }
}

class UnidadMovilAsignadaModel {
  final int? idUnidadMovil;
  final String nombreUnidad;
  final String? placa;

  const UnidadMovilAsignadaModel({
    required this.idUnidadMovil,
    required this.nombreUnidad,
    required this.placa,
  });

  factory UnidadMovilAsignadaModel.fromJson(Map<String, dynamic> json) {
    return UnidadMovilAsignadaModel(
      idUnidadMovil: _nullableInt(json['id_unidad_movil'] ?? json['id']),
      nombreUnidad: json['unidad_movil'] as String? ??
          json['nombre'] as String? ??
          json['codigo'] as String? ??
          'Unidad móvil asignada',
      placa: json['placa'] as String? ?? json['placa_unidad'] as String?,
    );
  }
}

Map<String, dynamic>? _mapFrom(Object? value) {
  return value is Map<String, dynamic> ? value : null;
}

Map<String, dynamic>? _flatTallerFrom(Map<String, dynamic> json) {
  final hasTaller = json['id_taller'] != null ||
      json['nombre_taller'] != null ||
      json['direccion_taller'] != null;
  if (!hasTaller) return null;
  return {
    'id_taller': json['id_taller'],
    'nombre_taller': json['nombre_taller'] ?? json['taller'],
    'direccion_taller': json['direccion_taller'],
    'telefono_contacto': json['telefono_contacto'] ?? json['telefono_taller'],
  };
}

Map<String, dynamic>? _flatTecnicoFrom(Map<String, dynamic> json) {
  final hasTecnico = json['id_tecnico'] != null ||
      json['nombre_tecnico'] != null ||
      json['telefono_tecnico'] != null;
  if (!hasTecnico) return null;
  return {
    'id_tecnico': json['id_tecnico'],
    'nombre_tecnico': json['nombre_tecnico'],
    'telefono_contacto': json['telefono_tecnico'] ?? json['telefono_contacto'],
  };
}

Map<String, dynamic>? _flatUnidadFrom(Map<String, dynamic> json) {
  final hasUnidad = json['id_unidad_movil'] != null ||
      json['unidad_movil'] != null ||
      json['placa'] != null;
  if (!hasUnidad) return null;
  return {
    'id_unidad_movil': json['id_unidad_movil'],
    'unidad_movil': json['unidad_movil'],
    'placa': json['placa'] ?? json['placa_unidad'],
  };
}

int _toInt(Object? value) {
  return _nullableInt(value) ?? 0;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
