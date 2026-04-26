import 'package:flutter/material.dart';

import '../../data/auth_state.dart';
import '../../data/role_redirect.dart';

class LoginPage extends StatefulWidget {
  final AuthState authState;

  const LoginPage({
    super.key,
    required this.authState,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _roles = const ['Cliente', 'Técnico', 'Taller', 'Admin'];

  String _selectedRole = 'Cliente';
  bool _rememberSession = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _localError = null);

    final success = await widget.authState.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberSession: _rememberSession,
    );

    if (!mounted) return;

    if (success && widget.authState.user != null) {
      Navigator.pushReplacementNamed(
        context,
        dashboardRouteFor(widget.authState.user!),
      );
      return;
    }

    setState(() {
      _localError = widget.authState.errorMessage ??
          'Correo o contraseña incorrectos';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authState,
      builder: (context, _) {
        final isLoading = widget.authState.status == AuthStatus.authenticating;

        return Scaffold(
          body: Stack(
            children: [
              const _SoftBackground(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BrandHeader(),
                            const SizedBox(height: 34),
                            Text(
                              'Bienvenido',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF26364F),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'de nuevo',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF26364F),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Ingresa tus credenciales para acceder al sistema.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF708198),
                                    height: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 34),
                            Text(
                              'Tipo de acceso',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: const Color(0xFF52657E),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _roles.map((role) {
                                final selected = role == _selectedRole;
                                return ChoiceChip(
                                  label: Text(role),
                                  selected: selected,
                                  showCheckmark: false,
                                  onSelected: isLoading
                                      ? null
                                      : (_) {
                                          setState(() {
                                            _selectedRole = role;
                                          });
                                        },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 32),
                            const _FieldLabel('Correo electrónico'),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'usuario@correo.com',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 24),
                            const _FieldLabel('Contraseña'),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !isLoading,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: '********',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberSession,
                                  onChanged: isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _rememberSession = value ?? false;
                                          });
                                        },
                                ),
                                const Expanded(
                                  child: Text(
                                    'Recordar sesión',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: isLoading ? null : () {},
                                  child: const Text('Recuperar contraseña'),
                                ),
                              ],
                            ),
                            if (_localError != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _localError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Iniciar sesión'),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('¿No tienes cuenta?'),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          Navigator.pushNamed(
                                            context,
                                            '/register-client',
                                          );
                                        },
                                  child: const Text('Regístrate'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (email.isEmpty) return 'Ingresa tu correo electrónico';
    if (!emailRegex.hasMatch(email)) return 'Ingresa un correo válido';
    return null;
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

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
          child: const Icon(
            Icons.navigation_rounded,
            color: Color(0xFF38D7F3),
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AutoAssist AI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF17253D),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Acceso seguro por rol',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A8CA4),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF52657E),
          ),
    );
  }
}

class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SoftBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SoftBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEAF8FF);
    canvas.drawRect(Offset.zero & size, paint);

    paint.color = const Color(0xFFD6F0FB).withValues(alpha: 0.9);
    canvas.drawCircle(Offset(size.width * 0.72, 76), 92, paint);
    canvas.drawCircle(Offset(-16, size.height * 0.24), 96, paint);
    canvas.drawCircle(Offset(size.width + 32, size.height * 0.44), 116, paint);
    canvas.drawCircle(Offset(size.width * 0.96, size.height * 0.84), 148, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
