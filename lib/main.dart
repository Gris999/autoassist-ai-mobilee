import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/autenticacion_seguridad/data/auth_state.dart';
import 'features/autenticacion_seguridad/data/role_redirect.dart';
import 'features/autenticacion_seguridad/presentation/screens/login_page.dart';
import 'features/autenticacion_seguridad/presentation/screens/register_client_screen.dart';
import 'features/gestion_clientes/presentation/screens/home_client_screen.dart';
import 'features/gestion_clientes/presentation/screens/role_dashboard_screen.dart';
import 'features/gestion_clientes/presentation/screens/vehicle_register_page.dart';
import 'features/gestion_incidentes_atencion/presentation/screens/client_incidents_page.dart';
import 'features/gestion_incidentes_atencion/presentation/screens/report_incident_page.dart';

void main() {
  runApp(const AutoAssistApp());
}

class AutoAssistApp extends StatefulWidget {
  const AutoAssistApp({super.key});

  @override
  State<AutoAssistApp> createState() => _AutoAssistAppState();
}

class _AutoAssistAppState extends State<AutoAssistApp> {
  late final AuthState _authState;

  @override
  void initState() {
    super.initState();
    _authState = AuthState();
  }

  @override
  void dispose() {
    _authState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoAssist AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => _SplashScreen(authState: _authState),
        '/login': (_) => LoginPage(authState: _authState),
        '/register-client': (_) => const RegisterClientScreen(),
        '/home-client': (_) => HomeClientScreen(authState: _authState),
        '/vehicle-register': (_) => VehicleRegisterPage(authState: _authState),
        '/report-incident': (_) => ReportIncidentPage(authState: _authState),
        '/client-incidents': (_) => ClientIncidentsPage(authState: _authState),
        '/dashboard-admin': (_) => RoleDashboardScreen(
              title: 'Dashboard admin',
              roleName: 'ADMIN',
              user: _authState.user,
              authState: _authState,
            ),
        '/dashboard-taller': (_) => RoleDashboardScreen(
              title: 'Dashboard taller',
              roleName: 'TALLER',
              user: _authState.user,
              authState: _authState,
            ),
        '/dashboard-tecnico': (_) => RoleDashboardScreen(
              title: 'Dashboard técnico',
              roleName: 'TECNICO',
              user: _authState.user,
              authState: _authState,
            ),
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  final AuthState authState;

  const _SplashScreen({required this.authState});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await widget.authState.restoreSession();

    if (!mounted) return;

    final user = widget.authState.user;
    Navigator.pushReplacementNamed(
      context,
      user == null ? '/login' : dashboardRouteFor(user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
