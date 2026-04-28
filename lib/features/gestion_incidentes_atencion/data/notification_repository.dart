import 'notification_models.dart';
import 'notification_service.dart';

class NotificationRepository {
  final NotificationService _service;

  NotificationRepository({NotificationService? service})
      : _service = service ?? NotificationService();

  Future<List<AppNotificationModel>> fetchNotifications(String accessToken) {
    return _service.fetchNotifications(accessToken);
  }

  Future<AppNotificationModel> fetchNotificationDetail({
    required int idNotificacion,
    required String accessToken,
  }) {
    return _service.fetchNotificationDetail(
      idNotificacion: idNotificacion,
      accessToken: accessToken,
    );
  }

  Future<void> markNotificationAsRead({
    required int idNotificacion,
    required String accessToken,
  }) {
    return _service.markNotificationAsRead(
      idNotificacion: idNotificacion,
      accessToken: accessToken,
    );
  }
}
