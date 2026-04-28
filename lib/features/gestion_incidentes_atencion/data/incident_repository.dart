import 'incident_models.dart';
import 'incident_service.dart';

class IncidentRepository {
  final IncidentService _service;

  IncidentRepository({IncidentService? service})
      : _service = service ?? IncidentService();

  Future<List<ClientIncident>> fetchMyIncidents(String accessToken) {
    return _service.fetchMyIncidents(accessToken);
  }

  Future<List<IncidentType>> fetchIncidentTypes(String accessToken) {
    return _service.fetchIncidentTypes(accessToken);
  }

  Future<Incident> createIncident({
    required String accessToken,
    required int idVehiculo,
    required int idTipoIncidente,
    required String titulo,
    required String descripcionTexto,
    required String direccionReferencia,
    required double latitud,
    required double longitud,
    List<IncidentEvidenceInput> evidencias = const [],
  }) {
    return _service.createIncident(
      accessToken: accessToken,
      idVehiculo: idVehiculo,
      idTipoIncidente: idTipoIncidente,
      titulo: titulo.trim(),
      descripcionTexto: descripcionTexto.trim(),
      direccionReferencia: direccionReferencia.trim(),
      latitud: latitud,
      longitud: longitud,
      evidencias: evidencias,
    );
  }

  Future<UploadedIncidentEvidence> uploadEvidence({
    required String accessToken,
    required String filePath,
  }) {
    return _service.uploadEvidence(
      accessToken: accessToken,
      filePath: filePath,
    );
  }

  Future<TranscribedAudioEvidence> transcribeAudioEvidence({
    required String accessToken,
    required String archivoUrl,
  }) {
    return _service.transcribeAudioEvidence(
      accessToken: accessToken,
      archivoUrl: archivoUrl,
    );
  }
}
