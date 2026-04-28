import 'package:flutter/foundation.dart';

class AppConfig {
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _lanBackendUrl = 'http://192.168.1.21:8000';
  static const _androidEmulatorBackendUrl = 'http://10.0.2.2:8000';

  static String get baseUrl {
    if (_baseUrlOverride.trim().isNotEmpty) {
      final normalized = _baseUrlOverride.trim();
      if (normalized.endsWith('/api/v1')) return normalized;
      return '$normalized/api/v1';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final host = kReleaseMode ? _lanBackendUrl : _androidEmulatorBackendUrl;
      return '$host/api/v1';
    }

    return 'http://127.0.0.1:8000/api/v1';
  }
}
