import 'package:flutter/material.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';

class HomeClientScreen extends StatelessWidget {
  final AuthState authState;

  const HomeClientScreen({
    super.key,
    required this.authState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio del cliente'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await authState.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _HomeCard(
              icon: Icons.person_add_alt_1,
              title: 'Mi perfil',
              subtitle: 'Datos del cliente',
              onTap: () {
                final user = authState.user;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      user == null
                          ? 'Usuario autenticado'
                          : 'Hola, ${user.displayName}',
                    ),
                  ),
                );
              },
            ),
            _HomeCard(
              icon: Icons.directions_car,
              title: 'Mis vehículos',
              subtitle: 'Registrar y consultar',
              onTap: () {
                Navigator.pushNamed(context, '/vehicle-register');
              },
            ),
            _HomeCard(
              icon: Icons.warning_amber_rounded,
              title: 'Reportar incidente',
              subtitle: 'Registrar emergencia',
              onTap: () {
                Navigator.pushNamed(context, '/report-incident');
              },
            ),
            _HomeCard(
              icon: Icons.track_changes,
              title: 'Estado del servicio',
              subtitle: 'Seguimiento del auxilio',
              onTap: () {
                Navigator.pushNamed(context, '/client-incidents');
              },
            ),
            _HomeCard(
              icon: Icons.notifications_active_outlined,
              title: 'Notificaciones',
              subtitle: 'Historial y avisos',
              onTap: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Color.fromRGBO(0, 0, 0, 0.08),
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: const Color(0xFF2563EB)),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
