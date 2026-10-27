import 'package:flutter/foundation.dart';

class ApiConstants {
  // Override at build/run time with --dart-define=API_BASE_URL=<URL>.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost.
      // For physical device on LAN, pass --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8080
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
  static const String meEndpoint = '/api/auth/me';
  static const String currentProfileEndpoint = '/api/user/profile';
  static const String itinerariesEndpoint = '/api/itineraries';
  static const String userItinerariesEndpoint = '/api/user/itineraries';
  static const String healthEndpoint = '/api/health';
}
