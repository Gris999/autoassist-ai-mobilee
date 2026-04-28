import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/auth_service.dart';

class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _repository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _repository.registerClient(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        celular: _celularController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta creada correctamente. Ahora puedes iniciar sesión.',
          ),
        ),
      );
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'No fue posible completar el registro';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _RegisterBackground(),
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
                        const _RegisterHeader(),
                        const SizedBox(height: 34),
                        Text(
                          'Crear cuenta',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: const Color(0xFF132033),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Regístrate como cliente para solicitar auxilio vehicular desde tu celular.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF6E7F96),
                                    height: 1.35,
                                  ),
                        ),
                        const SizedBox(height: 26),
                        _RegisterTextField(
                          label: 'Nombres',
                          controller: _nombresController,
                          icon: Icons.person_outline,
                          hintText: 'Ej. Pedro',
                          enabled: !_isLoading,
                          validator: (value) =>
                              _validateMinLength(value, 'nombres', 2),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _RegisterTextField(
                          label: 'Apellidos',
                          controller: _apellidosController,
                          icon: Icons.badge_outlined,
                          hintText: 'Ej. Lopez',
                          enabled: !_isLoading,
                          validator: (value) =>
                              _validateMinLength(value, 'apellidos', 2),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _RegisterTextField(
                          label: 'Celular',
                          controller: _celularController,
                          icon: Icons.phone_android_outlined,
                          hintText: 'Ej. 77777777',
                          enabled: !_isLoading,
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              _validateMinLength(value, 'celular', 7),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _RegisterTextField(
                          label: 'Correo electrónico',
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          hintText: 'pedro@example.com',
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _RegisterTextField(
                          label: 'Contraseña',
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          hintText: 'Mínimo 8 caracteres',
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RegisterTextField(
                          label: 'Confirmar contraseña',
                          controller: _confirmPasswordController,
                          icon: Icons.lock_outline,
                          hintText: 'Repite tu contraseña',
                          enabled: !_isLoading,
                          obscureText: _obscureConfirmPassword,
                          validator: _validateConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Registrarme'),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Ya tengo cuenta'),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      );
                                    },
                              child: const Text('Iniciar sesión'),
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
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tus $fieldName';
    }
    return null;
  }

  String? _validateMinLength(String? value, String fieldName, int minLength) {
    final text = value?.trim() ?? '';
    final requiredError = _required(text, fieldName);
    if (requiredError != null) return requiredError;
    if (text.length < minLength) {
      return 'Ingresa al menos $minLength caracteres';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (email.isEmpty) return 'Ingresa tu correo electrónico';
    if (!emailRegex.hasMatch(email)) return 'Ingresa un correo válido';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    if (value.length < 8) return 'La contraseña debe tener mínimo 8 caracteres';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }
}

class _RegisterTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _RegisterTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.enabled,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF52657E),
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF132033),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              'Registro seguro de cliente',
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

class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RegisterBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _RegisterBackgroundPainter extends CustomPainter {
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
