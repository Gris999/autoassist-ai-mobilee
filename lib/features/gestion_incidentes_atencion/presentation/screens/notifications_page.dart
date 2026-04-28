import 'package:flutter/material.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../data/notification_models.dart';
import '../../data/notification_repository.dart';
import '../../data/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  final AuthState authState;

  const NotificationsPage({
    super.key,
    required this.authState,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repository = NotificationRepository();

  List<AppNotificationModel> _notifications = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifications = await _repository.fetchNotifications(token);
      setState(() => _notifications = notifications);
    } on NotificationException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'No fue posible cargar las notificaciones';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openNotification(AppNotificationModel notification) async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    AppNotificationModel current = notification;

    try {
      current = await _repository.fetchNotificationDetail(
        idNotificacion: notification.idNotificacion,
        accessToken: token,
      );
    } on NotificationException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
    } catch (_) {
      // The list payload is enough to navigate if detail fetch fails.
    }

    try {
      await _repository.markNotificationAsRead(
        idNotificacion: current.idNotificacion,
        accessToken: token,
      );
      _markLocalAsRead(current.idNotificacion);
    } on NotificationException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
    } catch (_) {
      // Do not block navigation if marking as read fails.
    }

    if (!mounted) return;
    final idIncidente = current.idIncidente;
    if (idIncidente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación marcada como leída.')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/client-incidents',
      arguments: {
        'id_incidente': idIncidente,
        'destination': current.opensAssignment ? 'assignment' : 'detail',
      },
    );
  }

  void _markLocalAsRead(int idNotificacion) {
    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.idNotificacion == idNotificacion
                ? item.copyWith(leido: true)
                : item,
          )
          .toList();
    });
  }

  Future<void> _expireSession() async {
    await widget.authState.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: Stack(
        children: [
          const _NotificationsBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _NotificationsError(
                        message: _errorMessage!,
                        onRetry: _loadNotifications,
                      )
                    : _notifications.isEmpty
                        ? const _EmptyNotifications()
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final notification = _notifications[index];
                                return _NotificationTile(
                                  notification: notification,
                                  onTap: () => _openNotification(notification),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.leido
                ? const Color(0xFFD8E7F3)
                : const Color(0xFF0EA5E9),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Color.fromRGBO(15, 23, 42, 0.06),
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.leido
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: notification.leido
                    ? const Color(0xFF64748B)
                    : const Color(0xFF0EA5E9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.titulo,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (!notification.leido) const _UnreadDot(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.mensaje,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF52657E),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(notification.fechaEnvio),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6E7F96),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha no disponible';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(left: 8, top: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0EA5E9),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text('Todavía no tienes notificaciones.'),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 42),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar nuevamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBackground extends StatelessWidget {
  const _NotificationsBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotificationsBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _NotificationsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEAF8FF);
    canvas.drawRect(Offset.zero & size, paint);

    paint.color = const Color(0xFFD6F0FB).withValues(alpha: 0.9);
    canvas.drawCircle(Offset(size.width * 0.88, 34), 88, paint);
    canvas.drawCircle(Offset(-14, size.height * 0.36), 104, paint);
    canvas.drawCircle(Offset(size.width + 16, size.height * 0.86), 112, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
