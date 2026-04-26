import '../domain/auth_user.dart';

String dashboardRouteFor(AuthUser user) {
  if (user.hasRole('ADMIN')) return '/dashboard-admin';
  if (user.hasRole('TALLER')) return '/dashboard-taller';
  if (user.hasRole('TECNICO')) return '/dashboard-tecnico';
  if (user.hasRole('CLIENTE')) return '/home-client';
  return '/login';
}
