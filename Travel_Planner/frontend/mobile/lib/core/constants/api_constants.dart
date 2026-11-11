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
  static const String recommendationsEndpoint =
      '/api/itineraries/recommendations';
  static const String commentsEndpoint = '/comments';
  static const String userItinerariesEndpoint = '/api/user/itineraries';
  static const String destinationsEndpoint = '/api/destinations';
  static const String placesEndpoint = '/api/places';
  static const String healthEndpoint = '/api/health';
  static const String imageUploadEndpoint = '/api/media/images';
  static const String locationsEndpoint = '/api/locations';
  static const String locationSearchEndpoint = '/api/locations/search';
  static const String locationReverseGeocodeEndpoint =
      '/api/locations/reverse-geocode';
  static const String locationTomTomDetailsEndpoint =
      '/api/locations/providers/tomtom/details';
  static const String savedItinerariesEndpoint = '/api/user/saved-itineraries';
  static const String userFavoritesEndpoint = '/api/user/favorites';

  static String itinerarySaveEndpoint(int itineraryId) =>
      '/api/itineraries/$itineraryId/save';
  static String itineraryFavoritesEndpoint(int itineraryId) =>
      '/api/itineraries/$itineraryId/favorites';
  static String itineraryRatingsEndpoint(int itineraryId) =>
      '/api/itineraries/$itineraryId/ratings';
  static String itineraryUserRatingEndpoint(int itineraryId) =>
      '/api/itineraries/$itineraryId/ratings/me';
  static String itineraryPlacesEndpoint(int itineraryId) =>
      '/api/itineraries/$itineraryId/places';
  static String itineraryPlaceDeleteEndpoint(int itineraryId, int placeId) =>
      '/api/itineraries/$itineraryId/places/$placeId';
}
