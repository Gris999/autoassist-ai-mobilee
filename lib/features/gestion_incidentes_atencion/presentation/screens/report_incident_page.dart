import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  final _imageEvidenceDescriptionController = TextEditingController();
  final _audioEvidenceDescriptionController = TextEditingController();
  final _audioEvidenceTextController = TextEditingController();
  final _vehicleRepository = VehicleRepository();
  final _incidentRepository = IncidentRepository();
  final _locationService = LocationService();
  final _imagePickerService = IncidentImagePickerService();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _mapController = MapController();

  List<ClientVehicle> _vehicles = const [];
  List<IncidentType> _incidentTypes = const [];
  ClientVehicle? _selectedVehicle;
  IncidentType? _selectedIncidentType;
  LatLng _incidentLocation = _defaultLocation;
  bool _isLoadingInitialData = true;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _isRecordingAudio = false;
  bool _isUploadingAudio = false;
  bool _isTranscribingAudio = false;
  bool _isPlayingAudio = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<void>? _audioCompleteSubscription;
  XFile? _selectedImage;
  UploadedIncidentEvidence? _uploadedImageEvidence;
  String? _recordedAudioPath;
  UploadedIncidentEvidence? _uploadedAudioEvidence;
  String? _initialDataError;
  String? _locationMessage;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _loadInitialData();
    _useCurrentLocation(showLoading: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _imageEvidenceDescriptionController.dispose();
    _audioEvidenceDescriptionController.dispose();
    _audioEvidenceTextController.dispose();
    _recordingTimer?.cancel();
    _audioCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
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

  Future<void> _pickAndUploadImage(Future<XFile?> Function() action) async {
    final image = await action();
    if (image == null || !mounted) return;

    setState(() {
      _selectedImage = image;
      _uploadedImageEvidence = null;
      _submitError = null;
    });

    await _uploadPickedImage(image.path);
  }

  Future<void> _uploadPickedImage(String filePath) async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isUploadingImage = true;
      _submitError = null;
    });

    try {
      final uploaded = await _incidentRepository.uploadEvidence(
        accessToken: token,
        filePath: filePath,
      );
      setState(() {
        _uploadedImageEvidence = uploaded;
      });
    } on IncidentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _submitError = error.message);
    } catch (_) {
      setState(() {
        _submitError = 'No fue posible subir la evidencia de imagen.';
      });
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _removePickedImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageEvidence = null;
      _imageEvidenceDescriptionController.clear();
    });
  }

  Future<void> _startAudioRecording() async {
    setState(() => _submitError = null);

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        setState(() {
          _submitError = 'Permite el uso del micrófono para grabar audio.';
        });
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/incident_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioPlayer.stop();
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });

      setState(() {
        _isRecordingAudio = true;
        _isPlayingAudio = false;
        _recordingDuration = Duration.zero;
        _recordedAudioPath = path;
        _uploadedAudioEvidence = null;
      });
    } catch (_) {
      setState(() {
        _submitError = 'No fue posible iniciar la grabación de audio.';
      });
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecordingAudio = false;
        if (path != null && path.isNotEmpty) {
          _recordedAudioPath = path;
        }
      });

      final audioPath = path ?? _recordedAudioPath;
      if (audioPath != null && audioPath.isNotEmpty) {
        await _uploadRecordedAudio(audioPath);
      }
    } catch (_) {
      setState(() {
        _isRecordingAudio = false;
        _submitError = 'No fue posible detener la grabación de audio.';
      });
    }
  }

  Future<void> _uploadRecordedAudio(String filePath) async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isUploadingAudio = true;
      _submitError = null;
    });

    try {
      final uploaded = await _incidentRepository.uploadEvidence(
        accessToken: token,
        filePath: filePath,
      );
      setState(() {
        _uploadedAudioEvidence = uploaded;
        _isUploadingAudio = false;
      });
      await _transcribeUploadedAudio(uploaded.archivoUrl);
    } on IncidentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _submitError = error.message);
    } catch (_) {
      setState(() {
        _submitError = 'No fue posible subir la evidencia de audio.';
      });
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  Future<void> _transcribeUploadedAudio(String archivoUrl) async {
    final token = widget.authState.accessToken;
    if (token == null || token.isEmpty) {
      await _expireSession();
      return;
    }

    setState(() {
      _isTranscribingAudio = true;
      _submitError = null;
    });

    try {
      final transcription = await _incidentRepository.transcribeAudioEvidence(
        accessToken: token,
        archivoUrl: archivoUrl,
      );
      if (transcription.textoExtraido.trim().isNotEmpty) {
        final text = transcription.textoExtraido.trim();
        _audioEvidenceTextController.text = text;
        if (_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = text;
        }
      }
    } on IncidentException catch (error) {
      if (error.statusCode == 401) {
        await _expireSession();
        return;
      }
      setState(() => _submitError = error.message);
    } catch (_) {
      setState(() {
        _submitError = 'No fue posible transcribir el audio.';
      });
    } finally {
      if (mounted) setState(() => _isTranscribingAudio = false);
    }
  }

  Future<void> _removeRecordedAudio() async {
    if (_isRecordingAudio) {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();
    }
    await _audioPlayer.stop();

    setState(() {
      _isRecordingAudio = false;
      _isUploadingAudio = false;
      _isTranscribingAudio = false;
      _isPlayingAudio = false;
      _recordingDuration = Duration.zero;
      _recordedAudioPath = null;
      _uploadedAudioEvidence = null;
      _audioEvidenceDescriptionController.clear();
      _audioEvidenceTextController.clear();
    });
  }

  Future<void> _toggleAudioPlayback() async {
    final audioPath = _recordedAudioPath;
    if (audioPath == null || audioPath.isEmpty) return;

    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingAudio = false);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(audioPath));
      if (mounted) setState(() => _isPlayingAudio = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _submitError = 'No fue posible reproducir el audio grabado.';
        });
      }
    }
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
      setState(() => _submitError = 'No hay tipos de incidente disponibles.');
      return;
    }

    final evidencias = _buildEvidenceInputs();
    if (evidencias == null) return;

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
        titulo: _buildIncidentTitle(),
        descripcionTexto: _descriptionController.text,
        direccionReferencia: _addressController.text,
        latitud: _incidentLocation.latitude,
        longitud: _incidentLocation.longitude,
        evidencias: evidencias,
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
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
      ),
    );
  }

  List<IncidentEvidenceInput>? _buildEvidenceInputs() {
    final imageDescription = _imageEvidenceDescriptionController.text.trim();
    final audioDescription = _audioEvidenceDescriptionController.text.trim();
    final audioText = _audioEvidenceTextController.text.trim();
    final uploadedImage = _uploadedImageEvidence;
    final uploadedAudio = _uploadedAudioEvidence;

    if (uploadedImage == null &&
        imageDescription.isEmpty &&
        uploadedAudio == null &&
        audioDescription.isEmpty &&
        audioText.isEmpty) {
      return const [];
    }

    final evidencias = <IncidentEvidenceInput>[];

    if (_isUploadingImage) {
      setState(() {
        _submitError = 'Espera a que termine de subir la imagen.';
      });
      return null;
    }

    if (uploadedImage != null) {
      evidencias.add(
        IncidentEvidenceInput(
          tipoEvidencia: uploadedImage.tipoEvidencia,
          archivoUrl: uploadedImage.archivoUrl,
          descripcion:
              imageDescription.isEmpty ? 'Foto del daño' : imageDescription,
        ),
      );
    } else if (imageDescription.isNotEmpty) {
      setState(() {
        _submitError = 'Toma o elige una imagen antes de enviar su descripción.';
      });
      return null;
    }

    if (_isUploadingAudio) {
      setState(() {
        _submitError = 'Espera a que termine de subir el audio.';
      });
      return null;
    }

    if (_isTranscribingAudio) {
      setState(() {
        _submitError = 'Espera a que termine la transcripcion del audio.';
      });
      return null;
    }

    if (uploadedAudio != null) {
      evidencias.add(
        IncidentEvidenceInput(
          tipoEvidencia: uploadedAudio.tipoEvidencia,
          archivoUrl: uploadedAudio.archivoUrl,
          descripcion: audioDescription.isEmpty
              ? 'Audio grabado desde la app'
              : audioDescription,
          textoExtraido: audioText,
        ),
      );
    } else if (audioDescription.isNotEmpty || audioText.isNotEmpty) {
      setState(() {
        _submitError = 'Graba y sube un audio antes de enviar esos datos.';
      });
      return null;
    }

    return evidencias;
  }

  String _audioStatusText() {
    if (_isRecordingAudio) {
      return 'Grabando... ${_formatDuration(_recordingDuration)}';
    }
    if (_isUploadingAudio) {
      return 'Subiendo audio...';
    }
    if (_isTranscribingAudio) {
      return 'Transcribiendo audio...';
    }
    if (_isPlayingAudio) {
      return 'Reproduciendo audio...';
    }
    if (_uploadedAudioEvidence != null &&
        _audioEvidenceTextController.text.trim().isNotEmpty) {
      return 'Texto extraido correctamente';
    }
    if (_uploadedAudioEvidence != null) {
      return 'Audio cargado correctamente';
    }
    if (_recordedAudioPath != null) {
      return 'Audio grabado, pendiente de subida';
    }
    return 'Sin audio grabado';
  }

  String _imageStatusText() {
    if (_isUploadingImage) {
      return 'Subiendo imagen...';
    }
    if (_uploadedImageEvidence != null) {
      return 'Imagen cargada correctamente';
    }
    if (_selectedImage != null) {
      return 'Imagen seleccionada, pendiente de subida';
    }
    return 'Sin imagen seleccionada';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _fileName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  String _buildIncidentTitle() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return 'Incidente reportado';
    final firstLine = description.split(RegExp(r'[\n.!?]')).first.trim();
    final title = firstLine.isEmpty ? description : firstLine;
    if (title.length <= 58) return title;
    return '${title.substring(0, 58)}...';
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
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                const _IncidentClassificationNotice(),
                const SizedBox(height: 18),
                _SectionTitle('Detalles del incidente'),
                const SizedBox(height: 8),
                if (false) ...[
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSubmitting &&
                      !_isRecordingAudio &&
                      !_isTranscribingAudio,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Vehículo no enciende',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                  validator: (value) => _required(value, 'el título'),
                ),
                const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting &&
                      !_isTranscribingAudio,
                  minLines: 4,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Describe qué ocurrió y qué asistencia necesitas.',
                    prefixIcon: Icon(Icons.notes_outlined),
                    suffixIcon: IconButton(
                      tooltip: _isRecordingAudio
                          ? 'Detener grabacion'
                          : 'Grabar descripcion por audio',
                      onPressed: _isSubmitting ||
                              _isUploadingAudio ||
                              _isTranscribingAudio
                          ? null
                          : _isRecordingAudio
                              ? _stopAudioRecording
                              : _startAudioRecording,
                      icon: Icon(
                        _isRecordingAudio ? Icons.stop : Icons.mic_none,
                      ),
                    ),
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
                _SectionTitle('Evidencia opcional'),
                const SizedBox(height: 6),
                const Text(
                  'Etapa 0: prepara imagen o audio. Si grabas audio, se sube y se transcribe antes de reportar.',
                  style: TextStyle(color: Color(0xFF52657E)),
                ),
                const SizedBox(height: 10),
                _SectionTitle('Imagen'),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD8E7F3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _uploadedImageEvidence == null
                                  ? Icons.image_outlined
                                  : Icons.check_circle,
                              color: _uploadedImageEvidence == null
                                  ? const Color(0xFF52657E)
                                  : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _imageStatusText(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedImage != null) ...[
                          const SizedBox(height: 12),
                          _ImagePreview(
                            image: _selectedImage!,
                            onRemove: _isUploadingImage || _isSubmitting
                                ? null
                                : _removePickedImage,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting || _isUploadingImage
                                    ? null
                                    : () => _pickAndUploadImage(
                                          _imagePickerService.takePhoto,
                                        ),
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Tomar foto'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting || _isUploadingImage
                                    ? null
                                    : () => _pickAndUploadImage(
                                          _imagePickerService.pickFromGallery,
                                        ),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Galería'),
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
                  controller: _imageEvidenceDescriptionController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de imagen',
                    hintText: 'Ej. Foto del daño',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                if (false) ...[
                _SectionTitle('Audio'),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD8E7F3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isRecordingAudio
                                  ? Icons.mic
                                  : Icons.mic_none_outlined,
                              color: _isRecordingAudio
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF52657E),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _audioStatusText(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSubmitting ||
                                        _isUploadingAudio ||
                                        _isTranscribingAudio
                                    ? null
                                    : _isRecordingAudio
                                        ? _stopAudioRecording
                                        : _startAudioRecording,
                                icon: Icon(
                                  _isRecordingAudio
                                      ? Icons.stop
                                      : Icons.fiber_manual_record,
                                ),
                                label: Text(
                                  _isRecordingAudio
                                      ? 'Detener'
                                      : 'Grabar audio',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: _isPlayingAudio
                                  ? 'Detener audio'
                                  : 'Reproducir audio',
                              onPressed: _recordedAudioPath == null ||
                                      _isRecordingAudio ||
                                      _isUploadingAudio ||
                                      _isTranscribingAudio ||
                                      _isSubmitting
                                  ? null
                                  : _toggleAudioPlayback,
                              icon: Icon(
                                _isPlayingAudio
                                    ? Icons.stop_circle_outlined
                                    : Icons.play_circle_outline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Eliminar audio',
                              onPressed: (_recordedAudioPath == null &&
                                          _uploadedAudioEvidence == null) ||
                                      _isTranscribingAudio
                                  ? null
                                  : _removeRecordedAudio,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        if (_recordedAudioPath != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _fileName(_recordedAudioPath!),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF52657E)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _audioEvidenceDescriptionController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de audio',
                    hintText: 'Ej. Audio del cliente explicando el problema',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _audioEvidenceTextController,
                  enabled: !_isSubmitting,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Texto extraído del audio',
                    hintText: 'Opcional: transcripción si ya existe',
                    prefixIcon: Icon(Icons.transcribe_outlined),
                  ),
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
                  onPressed: _isSubmitting ||
                          _isUploadingImage ||
                          _isUploadingAudio ||
                          _isTranscribingAudio
                      ? null
                      : _submit,
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

  String get _incidentCode {
    return incident.idIncidente == 0
        ? 'INC creado'
        : 'INC-${incident.idIncidente}';
  }

  String get _reportedAtText {
    final value = incident.fechaReporte ?? DateTime.now();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String get _stateText {
    final state = incident.estadoServicioActual.trim();
    if (state.isEmpty) return 'Analizando incidente...';
    return state.replaceAll('_', ' ');
  }

  String get _priorityText {
    return incident.idPrioridad == 0
        ? 'Pendiente de analisis'
        : 'Prioridad #${incident.idPrioridad}';
  }

  String get _shortSummary {
    final summary = incident.resumenIa.trim();
    if (summary.length <= 130) return summary;
    return '${summary.substring(0, 130)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _IncidentBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _IncidentHeader(),
                      const SizedBox(height: 28),
                      const CircleAvatar(
                        radius: 46,
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
                      const SizedBox(height: 24),
                      Text(
                        'Incidente reportado correctamente',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        incident.requiereMasInfo
                            ? 'Necesitamos más información para procesar mejor tu incidente.'
                            : 'Estamos analizando tu incidente. Luego veras el resultado del analisis y la busqueda de talleres.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6E7F96),
                            ),
                      ),
                      const SizedBox(height: 22),
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
                                'Etapa 1: registro confirmado',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _incidentCode,
                                style: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ConfirmationRow(
                                icon: Icons.place_outlined,
                                text: incident.direccionReferencia.isEmpty
                                    ? 'Ubicacion registrada'
                                    : incident.direccionReferencia,
                              ),
                              const SizedBox(height: 8),
                              _ConfirmationRow(
                                icon: Icons.schedule_outlined,
                                text: _reportedAtText,
                              ),
                              const SizedBox(height: 8),
                              _ConfirmationRow(
                                icon: Icons.analytics_outlined,
                                text: 'Estado: $_stateText',
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Etapa 2: analisis y marketplace',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              _ConfirmationRow(
                                icon: Icons.flag_outlined,
                                text: 'Prioridad: $_priorityText',
                              ),
                              if (incident.clasificacionIa.isNotEmpty ||
                                  incident.resumenIa.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _ConfirmationRow(
                                  icon: Icons.psychology_outlined,
                                  text:
                                  incident.clasificacionIa.isEmpty
                                      ? 'Análisis automático iniciado'
                                      : 'Tipo detectado: ${incident.clasificacionIa}',
                                ),
                                if (incident.confianzaClasificacion > 0) ...[
                                  const SizedBox(height: 8),
                                  _ConfirmationRow(
                                    icon: Icons.speed_outlined,
                                    text:
                                    'Confianza: ${(incident.confianzaClasificacion * 100).round()}%',
                                  ),
                                ],
                                if (incident.resumenIa.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _ConfirmationRow(
                                    icon: Icons.notes_outlined,
                                    text: _shortSummary,
                                  ),
                                ],
                              ] else ...[
                                const SizedBox(height: 8),
                                const _ConfirmationRow(
                                  icon: Icons.hourglass_top_outlined,
                                  text:
                                      'Analisis automatico y busqueda de talleres en proceso.',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          '/client-incidents',
                        ),
                        child: const Text('Ver seguimiento actualizado'),
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

class _ConfirmationRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConfirmationRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF52657E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF334155)),
          ),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile image;
  final VoidCallback? onRemove;

  const _ImagePreview({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  borderRadius: BorderRadius.circular(8),
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

class _IncidentClassificationNotice extends StatelessWidget {
  const _IncidentClassificationNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E7F3)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: Color(0xFF52657E),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'La categoria final la clasificara la IA despues de enviar el incidente.',
                style: TextStyle(color: Color(0xFF52657E), height: 1.35),
              ),
            ),
          ],
        ),
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
