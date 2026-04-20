import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/autenticacion_seguridad/presentation/screens/login_screen.dart';
import 'features/autenticacion_seguridad/presentation/screens/register_client_screen.dart';
import 'features/gestion_clientes/presentation/screens/home_client_screen.dart';

void main() {
  runApp(const AutoAssistApp());
}

class AutoAssistApp extends StatelessWidget {
  const AutoAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoAssist AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register-client': (_) => const RegisterClientScreen(),
        '/home-client': (_) => const HomeClientScreen(),
      },
    );
  }
}