import 'incident_assignment_models.dart';
import 'incident_assignment_service.dart';

class IncidentAssignmentRepository {
  final IncidentAssignmentService _service;

  IncidentAssignmentRepository({IncidentAssignmentService? service})
      : _service = service ?? IncidentAssignmentService();

  Future<IncidentAssignmentModel> fetchIncidentAssignment({
    required int idIncidente,
    required String accessToken,
  }) {
    return _service.fetchIncidentAssignment(
      idIncidente: idIncidente,
      accessToken: accessToken,
    );
  }
}
