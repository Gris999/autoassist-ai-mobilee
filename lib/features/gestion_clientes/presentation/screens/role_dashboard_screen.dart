import 'package:flutter/material.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../../autenticacion_seguridad/domain/auth_user.dart';

class RoleDashboardScreen extends StatelessWidget {
  final String title;
  final String roleName;
  final AuthUser? user;
  final AuthState authState;

  const RoleDashboardScreen({
    super.key,
    required this.title,
    required this.roleName,
    required this.user,
    required this.authState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel $roleName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                user == null
                    ? 'Sesión iniciada.'
                    : 'Hola, ${user!.displayName}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rol confirmado desde /auth/me: $roleName',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
