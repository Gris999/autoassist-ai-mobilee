import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../autenticacion_seguridad/data/auth_state.dart';
import '../../../gestion_clientes/data/vehicle_models.dart';
import '../../../gestion_clientes/data/vehicle_repository.dart';
import '../../../gestion_clientes/data/vehicle_service.dart';
import '../../data/image_picker_service.dart';
import '../../data/incident_models.dart';
import '../../data/incident_repository.dart';
import '../../data/incident_service.dart';
import '../../data/location_service.dart';

class ReportIncidentPage extends StatefulWidget {
  final AuthState authState;

  const ReportIncidentPage({
    super.key,
    required this.authState,
  });

  @override
  State<ReportIncidentPage> createState() => _ReportIncidentPageState();
}

class _ReportIncidentPageState extends State<ReportIncidentPage> {
  static const _defaultLocation = LatLng(-17.7833, -63.1821);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleRepository = VehicleRepository();
  final _incidentRepository = IncidentRepository();
  final _locationService = LocationService();
  final _imagePickerService = IncidentImagePickerService();
  final _mapController = MapController();

  List<ClientVehicle> _vehicles = const [];
  List<IncidentType> _incidentTypes = const [];
  ClientVehicle? _selectedVehicle;
  IncidentType? _selectedIncidentType;
  LatLng _incidentLocation = _defaultLocation;
  XFile? _evidenceImage;
  bool _isLoadingInitialData = true;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  String? _initialDataError;
  String? _locationMessage;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _useCurrentLocation(showLoading: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isLoadingInitialData = true;
      _initialDataError = null;
    });

    try {
      final vehicles = await _vehicleRepository.fetchClientVehicles(token);
      final incidentTypes = await _incidentRepository.fetchIncidentTypes(token);
      debugPrint(
        'CU6 catalogos: vehiculos=${vehicles.length}, '
        'tipos_incidente=${incidentTypes.map((type) => {
              'id_tipo_incidente': type.idTipoIncidente,
              'nombre': type.nombre,
              'descripcion': type.descripcion,
            }).toList()}',
      );
      setState(() {
        _vehicles = vehicles;
        _selectedVehicle = vehicles.isEmpty ? null : vehicles.first;
        _incidentTypes = incidentTypes;
        _selectedIncidentType =
            incidentTypes.isEmpty ? null : incidentTypes.first;
      });
    } on VehicleException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _initialDataError = error.message);
    } on IncidentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _initialDataError = error.message);
    } catch (_) {
      setState(() {
        _initialDataError = 'No fue posible cargar los datos del reporte';
      });
    } finally {
      if (mounted) setState(() => _isLoadingInitialData = false);
    }
  }

  Future<void> _useCurrentLocation({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingLocation = true;
        _locationMessage = 'Obteniendo ubicación actual...';
      });
    }

    try {
      final location = await _locationService.getCurrentLocation();
      setState(() {
        _incidentLocation = location;
        _locationMessage = null;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = 'Ubicación actual compartida';
        }
      });
      _mapController.move(location, 15);
    } on LocationException catch (error) {
      setState(() => _locationMessage = error.message);
    } catch (_) {
      setState(() {
        _locationMessage =
            'No se pudo obtener tu ubicación. Puedes mover el pin manualmente.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _pickImage(Future<XFile?> Function() action) async {
    final image = await action();
    if (image == null || !mounted) return;
    setState(() => _evidenceImage = image);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final token = widget.authState.accessToken;
    final vehicle = _selectedVehicle;
    final incidentType = _selectedIncidentType;

    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    if (vehicle == null) {
      setState(() => _submitError = 'Primero debes registrar un vehículo.');
      return;
    }

    if (incidentType == null) {
      setState(() => _submitError = 'Selecciona un tipo de incidente.');
      return;
    }

    debugPrint(
      'CU6 seleccionado: id_vehiculo=${vehicle.idVehiculo}, '
      'id_tipo_incidente=${incidentType.idTipoIncidente}, '
      'titulo="${_titleController.text.trim()}", '
      'descripcion_vacia=${_descriptionController.text.trim().isEmpty}',
    );

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final incident = await _incidentRepository.createIncident(
        accessToken: token,
        idVehiculo: vehicle.idVehiculo,
        idTipoIncidente: incidentType.idTipoIncidente,
        titulo: _titleController.text,
        descripcionTexto: _descriptionController.text,
        direccionReferencia: _addressController.text,
        latitud: _incidentLocation.latitude,
        longitud: _incidentLocation.longitude,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => IncidentCreatedPage(incident: incident),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidente reportado correctamente.')),
      );
    } on IncidentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _submitError = error.message);
    } catch (_) {
      setState(() => _submitError = 'No fue posible reportar el incidente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      appBar: AppBar(title: const Text('Reportar incidente')),
      body: Stack(
        children: [
          const _IncidentBackground(),
          SafeArea(
            child: _isLoadingInitialData
                ? const Center(child: Text('Cargando tus vehículos...'))
                : _initialDataError != null
                    ? _LoadError(
                        message: _initialDataError!,
                        onRetry: _loadInitialData,
                      )
                    : _vehicles.isEmpty
                        ? const _NoVehicles()
                        : _incidentTypes.isEmpty
                            ? _LoadError(
                                message:
                                    'No hay tipos de incidente disponibles.',
                                onRetry: _loadInitialData,
                              )
                        : _buildForm(context),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _IncidentHeader(),
                const SizedBox(height: 30),
                Text(
                  'Reportar incidente',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF132033),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona el vehículo, describe el problema y confirma la ubicación.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6E7F96),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Vehículo'),
                const SizedBox(height: 8),
                DropdownButtonFormField<ClientVehicle>(
                  initialValue: _selectedVehicle,
                  items: _vehicles
                      .map(
                        (vehicle) => DropdownMenuItem(
                          value: vehicle,
                          child: Text('${vehicle.displayName} - ${vehicle.placa}'),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _selectedVehicle = value),
                  validator: (value) =>
                      value == null ? 'Selecciona un vehículo' : null,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Tipo de incidente'),
                const SizedBox(height: 8),
                DropdownButtonFormField<IncidentType>(
                  initialValue: _selectedIncidentType,
                  isExpanded: true,
                  items: _incidentTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _selectedIncidentType = value);
                          debugPrint(
                            'CU6 tipo seleccionado: '
                            'id_tipo_incidente=${value?.idTipoIncidente}',
                          );
                        },
                  validator: (value) =>
                      value == null ? 'Selecciona un tipo de incidente' : null,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.report_problem_outlined),
                  ),
                ),
                if (_selectedIncidentType != null) ...[
                  const SizedBox(height: 10),
                  _IncidentTypeHint(type: _selectedIncidentType!),
                ],
                const SizedBox(height: 18),
                _SectionTitle('Detalles del incidente'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Vehículo no enciende',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                  validator: (value) => _required(value, 'el título'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Describe qué ocurrió y qué asistencia necesitas.',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (value) => _required(value, 'la descripción'),
                ),
                const SizedBox(height: 18),
                _SectionTitle('Ubicación'),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed:
                      _isLoadingLocation ? null : () => _useCurrentLocation(),
                  icon: _isLoadingLocation
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isLoadingLocation
                        ? 'Obteniendo ubicación actual...'
                        : 'Usar mi ubicación actual',
                  ),
                ),
                if (_locationMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _locationMessage!,
                    style: const TextStyle(color: Color(0xFFB45309)),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _incidentLocation,
                        initialZoom: 14,
                        onTap: (_, point) {
                          setState(() {
                            _incidentLocation = point;
                            if (_addressController.text.trim().isEmpty) {
                              _addressController.text =
                                  'Ubicación ajustada en el mapa';
                            }
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mobile',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _incidentLocation,
                              width: 48,
                              height: 48,
                              child: const Icon(
                                Icons.location_pin,
                                color: Color(0xFFDC2626),
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de referencia',
                    hintText: 'Ej. Av. Banzer, 4to anillo',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (value) =>
                      _required(value, 'la dirección de referencia'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lat: ${_incidentLocation.latitude.toStringAsFixed(6)}  '
                  'Lng: ${_incidentLocation.longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6E7F96),
                      ),
                ),
                const SizedBox(height: 18),
                _SectionTitle('Evidencia visual'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _pickImage(_imagePickerService.takePhoto),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _pickImage(
                                  _imagePickerService.pickFromGallery,
                                ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
                if (_evidenceImage != null) ...[
                  const SizedBox(height: 12),
                  _ImagePreview(
                    image: _evidenceImage!,
                    onRemove: _isSubmitting
                        ? null
                        : () => setState(() => _evidenceImage = null),
                  ),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submitError!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Reportar incidente'),
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
}

class IncidentCreatedPage extends StatelessWidget {
  final Incident incident;

  const IncidentCreatedPage({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _IncidentBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _IncidentHeader(),
                      const SizedBox(height: 42),
                      const CircleAvatar(
                        radius: 56,
                        backgroundColor: Color(0xFFD6F8E1),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Solicitud registrada',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu incidente fue enviado correctamente y quedó disponible para atención.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6E7F96),
                            ),
                      ),
                      const SizedBox(height: 28),
                      DecoratedBox(
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
                              const Text(
                                'Identificador del incidente',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                incident.idIncidente == 0
                                    ? 'INC creado'
                                    : 'INC-${incident.idIncidente}',
                                style: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/home-client'),
                        child: const Text('Volver al inicio'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile image;
  final VoidCallback? onRemove;

  const _ImagePreview({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E7F3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    snapshot.data!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar imagen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoVehicles extends StatelessWidget {
  const _NoVehicles();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined, size: 46),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes vehículos registrados',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Primero debes registrar un vehículo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/vehicle-register'),
              child: const Text('Registrar vehículo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

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
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF26364F),
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _IncidentTypeHint extends StatelessWidget {
  final IncidentType type;

  const _IncidentTypeHint({required this.type});

  @override
  Widget build(BuildContext context) {
    final description = type.descripcion.trim();

    if (description.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E7F3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 18,
              color: Color(0xFF52657E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF52657E),
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentHeader extends StatelessWidget {
  const _IncidentHeader();

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
              'Solicitud de auxilio',
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

class _IncidentBackground extends StatelessWidget {
  const _IncidentBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IncidentBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _IncidentBackgroundPainter extends CustomPainter {
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
