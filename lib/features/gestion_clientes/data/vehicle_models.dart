class VehicleType {
  final int idTipoVehiculo;
  final String nombre;

  const VehicleType({
    required this.idTipoVehiculo,
    required this.nombre,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      idTipoVehiculo: json['id_tipo_vehiculo'] as int? ??
          json['id'] as int? ??
          json['id_tipo'] as int? ??
          0,
      nombre: json['nombre'] as String? ??
          json['tipo'] as String? ??
          json['descripcion'] as String? ??
          'Tipo de vehículo',
    );
  }
}

class VehicleRegistration {
  final int idVehiculo;
  final int idCliente;
  final int idTipoVehiculo;
  final String placa;
  final String marca;
  final String modelo;
  final int anio;
  final String color;
  final String descripcionReferencia;
  final bool estado;

  const VehicleRegistration({
    required this.idVehiculo,
    required this.idCliente,
    required this.idTipoVehiculo,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.color,
    required this.descripcionReferencia,
    required this.estado,
  });

  factory VehicleRegistration.fromJson(Map<String, dynamic> json) {
    return VehicleRegistration(
      idVehiculo: json['id_vehiculo'] as int? ?? 0,
      idCliente: json['id_cliente'] as int? ?? 0,
      idTipoVehiculo: json['id_tipo_vehiculo'] as int? ?? 0,
      placa: json['placa'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      anio: json['anio'] as int? ?? 0,
      color: json['color'] as String? ?? '',
      descripcionReferencia: json['descripcion_referencia'] as String? ?? '',
      estado: json['estado'] as bool? ?? false,
    );
  }
}

class ClientVehicle {
  final int idVehiculo;
  final int idTipoVehiculo;
  final String placa;
  final String marca;
  final String modelo;
  final int anio;
  final String color;
  final String descripcionReferencia;
  final bool estado;

  const ClientVehicle({
    required this.idVehiculo,
    required this.idTipoVehiculo,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.color,
    required this.descripcionReferencia,
    required this.estado,
  });

  factory ClientVehicle.fromJson(Map<String, dynamic> json) {
    return ClientVehicle(
      idVehiculo: json['id_vehiculo'] as int? ?? json['id'] as int? ?? 0,
      idTipoVehiculo: json['id_tipo_vehiculo'] as int? ?? 0,
      placa: json['placa'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      anio: json['anio'] as int? ?? 0,
      color: json['color'] as String? ?? '',
      descripcionReferencia: json['descripcion_referencia'] as String? ?? '',
      estado: json['estado'] as bool? ?? true,
    );
  }

  String get displayName {
    final name = '$marca $modelo'.trim();
    return name.isEmpty ? placa : name;
  }
}
