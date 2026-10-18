import 'package:flutter/foundation.dart';

class ApiConstants {
  // Override at build/run time with --dart-define=API_BASE_URL=<URL>.
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // The current development computer's LAN address, for a physical phone.
      return 'http://192.168.1.9:8080';
    }
    return 'http://localhost:8080';
  }

  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
  static const String currentProfileEndpoint = '/api/user/profile';
  static const String healthEndpoint = '/api/health';
}
