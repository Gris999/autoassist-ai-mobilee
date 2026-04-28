import 'package:flutter/material.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../data/vehicle_models.dart';
import '../../data/vehicle_repository.dart';
import '../../data/vehicle_service.dart';

class VehicleRegisterPage extends StatefulWidget {
  final AuthState authState;

  const VehicleRegisterPage({
    super.key,
    required this.authState,
  });

  @override
  State<VehicleRegisterPage> createState() => _VehicleRegisterPageState();
}

class _VehicleRegisterPageState extends State<VehicleRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  final _repository = VehicleRepository();

  List<VehicleType> _types = const [];
  VehicleType? _selectedType;
  bool _isLoadingTypes = true;
  bool _isSubmitting = false;
  String? _catalogError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isLoadingTypes = true;
      _catalogError = null;
    });

    try {
      final types = await _repository.fetchVehicleTypes(token);
      setState(() {
        _types = types;
        _selectedType = types.isEmpty ? null : types.first;
      });
    } on VehicleException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }

      setState(() => _catalogError = error.message);
    } catch (_) {
      setState(() {
        _catalogError = 'No fue posible cargar tipos de vehículo';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingTypes = false);
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final token = widget.authState.accessToken;
    final selectedType = _selectedType;

    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    if (selectedType == null) {
      setState(() => _submitError = 'Selecciona un tipo de vehículo');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await _repository.registerVehicle(
        accessToken: token,
        idTipoVehiculo: selectedType.idTipoVehiculo,
        placa: _placaController.text,
        marca: _marcaController.text,
        modelo: _modeloController.text,
        anio: int.parse(_anioController.text.trim()),
        color: _colorController.text,
      );

      if (!mounted) return;

      _formKey.currentState!.reset();
      _placaController.clear();
      _marcaController.clear();
      _modeloController.clear();
      _anioController.clear();
      _colorController.clear();
      setState(() {
        _selectedType = _types.isEmpty ? null : _types.first;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehículo registrado correctamente'),
        ),
      );
    } on VehicleException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }

      setState(() => _submitError = error.message);
    } catch (_) {
      setState(() {
        _submitError = 'No fue posible registrar el vehículo';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
      appBar: AppBar(
        title: const Text('Registrar vehículo'),
      ),
      body: Stack(
        children: [
          const _VehicleBackground(),
          SafeArea(
            child: _isLoadingTypes
                ? const Center(child: CircularProgressIndicator())
                : _catalogError != null
                    ? _CatalogError(
                        message: _catalogError!,
                        onRetry: _loadTypes,
                      )
                    : _VehicleForm(
                        formKey: _formKey,
                        types: _types,
                        selectedType: _selectedType,
                        onTypeChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() => _selectedType = value);
                              },
                        placaController: _placaController,
                        marcaController: _marcaController,
                        modeloController: _modeloController,
                        anioController: _anioController,
                        colorController: _colorController,
                        isSubmitting: _isSubmitting,
                        submitError: _submitError,
                        onSubmit: _submit,
                        onCancel: () => Navigator.pop(context),
                      ),
          ),
        ],
      ),
    );
  }
}

class _VehicleForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<VehicleType> types;
  final VehicleType? selectedType;
  final ValueChanged<VehicleType?>? onTypeChanged;
  final TextEditingController placaController;
  final TextEditingController marcaController;
  final TextEditingController modeloController;
  final TextEditingController anioController;
  final TextEditingController colorController;
  final bool isSubmitting;
  final String? submitError;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _VehicleForm({
    required this.formKey,
    required this.types,
    required this.selectedType,
    required this.onTypeChanged,
    required this.placaController,
    required this.marcaController,
    required this.modeloController,
    required this.anioController,
    required this.colorController,
    required this.isSubmitting,
    required this.submitError,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VehicleHeader(),
                const SizedBox(height: 34),
                Text(
                  'Registrar vehículo',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF132033),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa los datos principales del vehículo para asociarlo a tu cuenta.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6E7F96),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Tipo de vehículo',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF52657E),
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<VehicleType>(
                  initialValue: selectedType,
                  items: types
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: onTypeChanged,
                  validator: (value) {
                    if (value == null) return 'Selecciona un tipo de vehículo';
                    return null;
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                _VehicleTextField(
                  label: 'Placa',
                  controller: placaController,
                  icon: Icons.confirmation_number_outlined,
                  hintText: 'Ej. 1234ABC',
                  enabled: !isSubmitting,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) => _required(value, 'placa'),
                ),
                const SizedBox(height: 16),
                _VehicleTextField(
                  label: 'Marca',
                  controller: marcaController,
                  icon: Icons.directions_car_outlined,
                  hintText: 'Ej. Toyota',
                  enabled: !isSubmitting,
                  validator: (value) => _required(value, 'marca'),
                ),
                const SizedBox(height: 16),
                _VehicleTextField(
                  label: 'Modelo',
                  controller: modeloController,
                  icon: Icons.car_repair_outlined,
                  hintText: 'Ej. Corolla',
                  enabled: !isSubmitting,
                  validator: (value) => _required(value, 'modelo'),
                ),
                const SizedBox(height: 16),
                _VehicleTextField(
                  label: 'Año',
                  controller: anioController,
                  icon: Icons.calendar_today_outlined,
                  hintText: 'Ej. 2020',
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.number,
                  validator: _validateYear,
                ),
                const SizedBox(height: 16),
                _VehicleTextField(
                  label: 'Color',
                  controller: colorController,
                  icon: Icons.palette_outlined,
                  hintText: 'Ej. Blanco',
                  enabled: !isSubmitting,
                  validator: (value) => _required(value, 'color'),
                ),
                if (submitError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    submitError!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  child: isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Registrar vehículo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: isSubmitting ? null : onCancel,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa $fieldName';
    }
    return null;
  }

  String? _validateYear(String? value) {
    final text = value?.trim() ?? '';
    final year = int.tryParse(text);
    final maxYear = DateTime.now().year + 1;

    if (text.isEmpty) return 'Ingresa el año';
    if (year == null) return 'El año debe ser numérico';
    if (year < 1950 || year > maxYear) {
      return 'Ingresa un año entre 1950 y $maxYear';
    }

    return null;
  }
}

class _VehicleTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?) validator;

  const _VehicleTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.enabled,
    required this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
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
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon),
          ),
        ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CatalogError({
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
            const Icon(
              Icons.error_outline,
              color: Color(0xFFDC2626),
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader();

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
              'Gestión de vehículos',
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

class _VehicleBackground extends StatelessWidget {
  const _VehicleBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VehicleBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _VehicleBackgroundPainter extends CustomPainter {
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
