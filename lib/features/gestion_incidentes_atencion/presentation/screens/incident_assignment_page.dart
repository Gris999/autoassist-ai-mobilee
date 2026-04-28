import 'package:flutter/material.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../data/incident_assignment_models.dart';
import '../../data/incident_assignment_repository.dart';
import '../../data/incident_assignment_service.dart';

class IncidentAssignmentPage extends StatefulWidget {
  final int idIncidente;
  final AuthState authState;

  const IncidentAssignmentPage({
    super.key,
    required this.idIncidente,
    required this.authState,
  });

  @override
  State<IncidentAssignmentPage> createState() => _IncidentAssignmentPageState();
}

class _IncidentAssignmentPageState extends State<IncidentAssignmentPage> {
  final _repository = IncidentAssignmentRepository();

  IncidentAssignmentModel? _assignment;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
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
      final assignment = await _repository.fetchIncidentAssignment(
        idIncidente: widget.idIncidente,
        accessToken: token,
      );
      setState(() => _assignment = assignment);
    } on IncidentAssignmentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'No fue posible cargar la asignación del auxilio';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      appBar: AppBar(title: Text('Asignación INC-${widget.idIncidente}')),
      body: Stack(
        children: [
          const _AssignmentBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _AssignmentError(
                        message: _errorMessage!,
                        onRetry: _loadAssignment,
                      )
                    : _AssignmentContent(assignment: _assignment!),
          ),
        ],
      ),
    );
  }
}

class _AssignmentContent extends StatelessWidget {
  final IncidentAssignmentModel assignment;

  const _AssignmentContent({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _AssignmentHeader(),
        const SizedBox(height: 24),
        _SummaryPanel(assignment: assignment),
        const SizedBox(height: 16),
        _StatusPanel(assignment: assignment),
        const SizedBox(height: 16),
        _TallerPanel(taller: assignment.taller),
        const SizedBox(height: 16),
        _TecnicoPanel(tecnico: assignment.tecnico),
        const SizedBox(height: 16),
        _UnidadPanel(unidad: assignment.unidadMovil),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final IncidentAssignmentModel assignment;

  const _SummaryPanel({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: assignment.titulo,
      children: [
        _InfoRow(icon: Icons.confirmation_number_outlined, text: 'INC-${assignment.idIncidente}'),
        if (assignment.tipoIncidente.isNotEmpty)
          _InfoRow(icon: Icons.report_problem_outlined, text: assignment.tipoIncidente),
        if ((assignment.placaVehiculo ?? '').isNotEmpty)
          _InfoRow(
            icon: Icons.directions_car_outlined,
            text:
                '${assignment.placaVehiculo} ${assignment.marcaVehiculo ?? ''} ${assignment.modeloVehiculo ?? ''}'.trim(),
          ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IncidentAssignmentModel assignment;

  const _StatusPanel({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Estado actual',
      children: [
        _StatusBadge(label: assignment.friendlyState),
        const SizedBox(height: 12),
        Text(
          assignment.assignmentSummary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF52657E),
                height: 1.35,
              ),
        ),
        if ((assignment.estadoAsignacion ?? '').isNotEmpty)
          _InfoRow(
            icon: Icons.assignment_turned_in_outlined,
            text: 'Asignación: ${assignment.estadoAsignacion}',
          ),
        if (assignment.tiempoEstimadoMin != null)
          _InfoRow(
            icon: Icons.timer_outlined,
            text: 'Tiempo estimado: ${assignment.tiempoEstimadoMin} min',
          ),
      ],
    );
  }
}

class _TallerPanel extends StatelessWidget {
  final TallerAsignadoModel? taller;

  const _TallerPanel({required this.taller});

  @override
  Widget build(BuildContext context) {
    if (taller == null) {
      return const _EmptyPanel(
        title: 'Taller asignado',
        message: 'Aún no hay un taller asignado.',
      );
    }

    return _Panel(
      title: 'Taller asignado',
      children: [
        _InfoRow(icon: Icons.store_mall_directory_outlined, text: taller!.nombreTaller),
        if ((taller!.direccionTaller ?? '').isNotEmpty)
          _InfoRow(icon: Icons.place_outlined, text: taller!.direccionTaller!),
        if ((taller!.telefonoContacto ?? '').isNotEmpty)
          _InfoRow(icon: Icons.phone_outlined, text: taller!.telefonoContacto!),
      ],
    );
  }
}

class _TecnicoPanel extends StatelessWidget {
  final TecnicoAsignadoModel? tecnico;

  const _TecnicoPanel({required this.tecnico});

  @override
  Widget build(BuildContext context) {
    if (tecnico == null) {
      return const _EmptyPanel(
        title: 'Técnico asignado',
        message: 'Pendiente de asignación de técnico.',
      );
    }

    return _Panel(
      title: 'Técnico asignado',
      children: [
        _InfoRow(icon: Icons.engineering_outlined, text: tecnico!.nombreTecnico),
        if ((tecnico!.telefonoContacto ?? '').isNotEmpty)
          _InfoRow(icon: Icons.phone_outlined, text: tecnico!.telefonoContacto!),
      ],
    );
  }
}

class _UnidadPanel extends StatelessWidget {
  final UnidadMovilAsignadaModel? unidad;

  const _UnidadPanel({required this.unidad});

  @override
  Widget build(BuildContext context) {
    if (unidad == null) {
      return const _EmptyPanel(
        title: 'Unidad móvil',
        message: 'Pendiente de asignación de unidad móvil.',
      );
    }

    return _Panel(
      title: 'Unidad móvil',
      children: [
        _InfoRow(icon: Icons.local_shipping_outlined, text: unidad!.nombreUnidad),
        if ((unidad!.placa ?? '').isNotEmpty)
          _InfoRow(icon: Icons.pin_outlined, text: 'Placa: ${unidad!.placa}'),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Panel({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E7F3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyPanel({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      children: [
        _InfoRow(icon: Icons.hourglass_empty_outlined, text: message),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignmentHeader extends StatelessWidget {
  const _AssignmentHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF12305A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.assignment_ind_outlined, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asignación del auxilio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF132033),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              'Taller, técnico y unidad móvil',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6E7F96),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssignmentError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AssignmentError({
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

class _AssignmentBackground extends StatelessWidget {
  const _AssignmentBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AssignmentBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _AssignmentBackgroundPainter extends CustomPainter {
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
