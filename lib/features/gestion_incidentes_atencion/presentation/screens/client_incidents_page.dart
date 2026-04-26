import 'package:flutter/material.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../data/incident_models.dart';
import '../../data/incident_repository.dart';
import '../../data/incident_service.dart';
import 'payment_page.dart';

class ClientIncidentsPage extends StatefulWidget {
  final AuthState authState;

  const ClientIncidentsPage({
    super.key,
    required this.authState,
  });

  @override
  State<ClientIncidentsPage> createState() => _ClientIncidentsPageState();
}

class _ClientIncidentsPageState extends State<ClientIncidentsPage> {
  final _repository = IncidentRepository();

  List<ClientIncident> _incidents = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
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
      final incidents = await _repository.fetchMyIncidents(token);
      setState(() => _incidents = incidents);
    } on IncidentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'No fue posible cargar el estado de tus servicios';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _expireSession() async {
    await widget.authState.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estado del servicio')),
      body: Stack(
        children: [
          const _StatusBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: Text('Cargando tus servicios...'))
                : _errorMessage != null
                    ? _StatusError(
                        message: _errorMessage!,
                        onRetry: _loadIncidents,
                      )
                    : _incidents.isEmpty
                        ? const _EmptyIncidents()
                        : _IncidentList(
                            incidents: _incidents,
                            authState: widget.authState,
                            onRefresh: _loadIncidents,
                          ),
          ),
        ],
      ),
    );
  }
}

class _IncidentList extends StatelessWidget {
  final List<ClientIncident> incidents;
  final AuthState authState;
  final Future<void> Function() onRefresh;

  const _IncidentList({
    required this.incidents,
    required this.authState,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        itemCount: incidents.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _StatusHeader();
          }

          final incident = incidents[index - 1];
          return _IncidentCard(incident: incident, authState: authState);
        },
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final ClientIncident incident;
  final AuthState authState;

  const _IncidentCard({
    required this.incident,
    required this.authState,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E7F3)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color.fromRGBO(15, 23, 42, 0.06),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    incident.titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF132033),
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusChip(label: incident.stateLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              incident.shortDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF52657E),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            _MetaRow(
              icon: Icons.schedule_outlined,
              text: _formatDate(incident.fechaReporte),
            ),
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.flag_outlined,
              text: incident.priorityLabel,
            ),
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.place_outlined,
              text: incident.direccionReferencia.isEmpty
                  ? 'Sin dirección registrada'
                  : incident.direccionReferencia,
            ),
            if (incident.requiereMasInfo) ...[
              const SizedBox(height: 12),
              const _MoreInfoChip(),
            ],
            if (incident.clasificacionIa.isNotEmpty ||
                incident.resumenIa.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AiSummary(incident: incident),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientIncidentDetailPage(
                        incident: incident,
                        authState: authState,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Ver detalle'),
              ),
            ),
          ],
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
    return 'Reportado $day/$month/${local.year}, $hour:$minute';
  }
}

class ClientIncidentDetailPage extends StatelessWidget {
  final ClientIncident incident;
  final AuthState authState;

  const ClientIncidentDetailPage({
    super.key,
    required this.incident,
    required this.authState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('INC-${incident.idIncidente}')),
      body: Stack(
        children: [
          const _StatusBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _StatusHeader(subtitle: 'Detalle del servicio'),
                const SizedBox(height: 24),
                _DetailPanel(incident: incident),
                const SizedBox(height: 18),
                _ProgressPanel(incident: incident),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentPage(
                          idIncidente: incident.idIncidente,
                          authState: authState,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Pagar auxilio'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver al listado'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final ClientIncident incident;

  const _DetailPanel({required this.incident});

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    incident.titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _StatusChip(label: incident.stateLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(incident.descripcionTexto),
            const SizedBox(height: 16),
            _MetaRow(icon: Icons.place_outlined, text: incident.direccionReferencia),
            const SizedBox(height: 8),
            _MetaRow(icon: Icons.flag_outlined, text: incident.priorityLabel),
            if (incident.resumenIa.isNotEmpty) ...[
              const SizedBox(height: 16),
              _AiSummary(incident: incident),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final ClientIncident incident;

  const _ProgressPanel({required this.incident});

  @override
  Widget build(BuildContext context) {
    final steps = const [
      (1, 'Reporte enviado'),
      (2, 'Pendiente de asignación'),
      (3, 'Auxilio asignado'),
      (4, 'En camino'),
      (5, 'En atención'),
      (6, 'Servicio finalizado'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E7F3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avance del servicio',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...steps.map((step) {
              final completed = step.$1 <= incident.idEstadoServicioActual;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      completed ? Icons.check_circle : Icons.circle_outlined,
                      color: completed
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(step.$2),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final String subtitle;

  const _StatusHeader({this.subtitle = 'Seguimiento de auxilio'});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF12305A),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AutoAssist AI',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF132033),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6E7F96),
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),
        Text(
          'Estado de mis servicios',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF132033),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Consulta el estado actual de tus incidentes reportados.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6E7F96),
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFD6F8E1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF16A34A),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MoreInfoChip extends StatelessWidget {
  const _MoreInfoChip();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFFFEDD5),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          'Requiere más información',
          style: TextStyle(
            color: Color(0xFFC2410C),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  final ClientIncident incident;

  const _AiSummary({required this.incident});

  @override
  Widget build(BuildContext context) {
    final confidence = (incident.confianzaClasificacion * 100).round();
    final title = incident.clasificacionIa.isEmpty
        ? 'Clasificación IA'
        : 'IA: ${incident.clasificacionIa}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (incident.confianzaClasificacion > 0) ...[
              const SizedBox(height: 4),
              Text('Confianza: $confidence%'),
            ],
            if (incident.resumenIa.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(incident.resumenIa),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF52657E),
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _EmptyIncidents extends StatelessWidget {
  const _EmptyIncidents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes incidentes reportados',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/report-incident'),
              child: const Text('Reportar incidente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StatusError({
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

class _StatusBackground extends StatelessWidget {
  const _StatusBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StatusBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _StatusBackgroundPainter extends CustomPainter {
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
