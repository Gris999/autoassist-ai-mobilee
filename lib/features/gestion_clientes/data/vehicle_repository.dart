import 'vehicle_models.dart';
import 'vehicle_service.dart';

class VehicleRepository {
  final VehicleService _service;

  VehicleRepository({VehicleService? service})
      : _service = service ?? VehicleService();

  Future<List<ClientVehicle>> fetchClientVehicles(String accessToken) {
    return _service.fetchClientVehicles(accessToken);
  }

  Future<List<VehicleType>> fetchVehicleTypes(String accessToken) {
    return _service.fetchVehicleTypes(accessToken);
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
  }) {
    return _service.registerVehicle(
      accessToken: accessToken,
      idTipoVehiculo: idTipoVehiculo,
      placa: placa.trim().toUpperCase(),
      marca: marca.trim(),
      modelo: modelo.trim(),
      anio: anio,
      color: color.trim(),
      descripcionReferencia: descripcionReferencia.trim(),
    );
  }
}
