import 'package:flutter/foundation.dart';

class AppConfig {
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.trim().isNotEmpty) {
      final normalized = _baseUrlOverride.trim();
      if (normalized.endsWith('/api/v1')) return normalized;
      return '$normalized/api/v1';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }

    return 'http://127.0.0.1:8000/api/v1';
  }
}
