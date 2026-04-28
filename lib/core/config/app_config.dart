class AppConfig {
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _cloudBackendUrl = 'https://autoassist-ai-backendd.onrender.com';

  static String get baseUrl {
    if (_baseUrlOverride.trim().isNotEmpty) {
      final normalized = _baseUrlOverride.trim();
      if (normalized.endsWith('/api/v1')) return normalized;
      return '$normalized/api/v1';
    }

    return '$_cloudBackendUrl/api/v1';
  }
}
