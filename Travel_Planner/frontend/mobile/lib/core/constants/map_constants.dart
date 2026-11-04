import 'package:latlong2/latlong.dart';

/// Centralized configuration and constants for map rendering,
/// free tile CDN endpoints, attribution notices, and camera defaults.
class MapConstants {
  MapConstants._();

  /// Map tile endpoint URL template.
  /// Defaults to CARTO Basemaps (Voyager) with retina support placeholder ({r}).
  /// Can be overridden at compile/run time via `--dart-define=MAP_TILE_URL_TEMPLATE=<URL>`.
  static const String tileUrlTemplate = String.fromEnvironment(
    'MAP_TILE_URL_TEMPLATE',
    defaultValue:
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  );

  /// Required attribution notice for tile providers.
  /// CARTO Basemaps and OpenStreetMap require visible attribution.
  /// Can be overridden via `--dart-define=MAP_TILE_ATTRIBUTION=<Notice>`.
  static const String tileAttribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors, © CARTO',
  );

  /// Tile server subdomains used for round-robin load distribution.
  static const List<String> defaultSubdomains = ['a', 'b', 'c', 'd'];

  /// Package identifier sent in tile requests' User-Agent header where permitted.
  static const String userAgentPackageName = String.fromEnvironment(
    'MAP_USER_AGENT_PACKAGE_NAME',
    defaultValue: 'com.travelplanner.mobile',
  );

  /// CARTO Basemaps API key for raster tile authentication.
  /// Can be configured at compile/run time via `--dart-define=CARTO_API_KEY=<key>`
  /// or `--dart-define=MAP_API_KEY=<key>`.
  static const String cartoApiKey = String.fromEnvironment(
    'CARTO_API_KEY',
    defaultValue: String.fromEnvironment('MAP_API_KEY', defaultValue: ''),
  );

  /// Whether a CARTO Basemaps API key is configured.
  static bool get hasCartoApiKey => cartoApiKey.trim().isNotEmpty;

  /// Appends or substitutes an API key into a tile URL template.
  ///
  /// - If [template] contains `{apiKey}` or `{key}`, it replaces the placeholder with the URL-encoded [apiKey].
  /// - If [apiKey] is non-empty and [template] does not yet specify a `key=` parameter:
  ///   Appends `key=<apiKey>` with proper `?` or `&` query delimiter.
  /// - If [apiKey] is null/empty or [template] already includes `key=`, returns [template] unchanged.
  static String appendApiKey(String template, {String? apiKey}) {
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty) {
      return template;
    }

    final encodedKey = Uri.encodeQueryComponent(key);

    if (template.contains('{apiKey}')) {
      return template.replaceAll('{apiKey}', encodedKey);
    }
    if (template.contains('{key}')) {
      return template.replaceAll('{key}', encodedKey);
    }

    // Check if key query parameter is already explicitly provided
    if (template.contains('?key=') ||
        template.contains('&key=') ||
        template.contains('?apiKey=') ||
        template.contains('&apiKey=')) {
      return template;
    }

    final separator = template.contains('?') ? '&' : '?';
    return '$template${separator}key=$encodedKey';
  }

  /// Returns the effective tile URL template with [cartoApiKey] applied if targeting CARTO.
  static String get effectiveTileUrlTemplate {
    if (tileUrlTemplate.contains('basemaps.cartocdn.com') ||
        tileUrlTemplate.contains('{key}') ||
        tileUrlTemplate.contains('{apiKey}')) {
      return appendApiKey(tileUrlTemplate, apiKey: cartoApiKey);
    }
    return tileUrlTemplate;
  }

  /// Returns whether the effective tile configuration requires a CARTO API key
  /// but none was supplied via environment variables.
  static bool get isCartoApiKeyMissing {
    final isCarto = tileUrlTemplate.contains('basemaps.cartocdn.com');
    if (!isCarto) return false;
    if (tileUrlTemplate.contains('?key=') ||
        tileUrlTemplate.contains('&key=') ||
        tileUrlTemplate.contains('?apiKey=') ||
        tileUrlTemplate.contains('&apiKey=')) {
      return false;
    }
    return !hasCartoApiKey;
  }

  /// Neutral country-level geographic centroid of Vietnam (14.0583° N, 108.2772° E).
  /// Provides an unbiased, country-wide overview (zoom ~6.0) without assuming
  /// or favoring any specific city (Hanoi, Da Nang, Ho Chi Minh City).
  static const double neutralCountryCentroidLatitude = 14.0583;
  static const double neutralCountryCentroidLongitude = 108.2772;
  static const double neutralCountryCentroidZoom = 6.0;

  // Private environment string definitions for double parsing.
  // Note: Dart core supports bool.fromEnvironment, int.fromEnvironment, and String.fromEnvironment;
  // double values are parsed from String.fromEnvironment with safe fallbacks.
  static const String _defaultLatEnv = String.fromEnvironment(
    'DEFAULT_MAP_LATITUDE',
    defaultValue: '14.0583',
  );

  static const String _defaultLngEnv = String.fromEnvironment(
    'DEFAULT_MAP_LONGITUDE',
    defaultValue: '108.2772',
  );

  static const String _defaultZoomEnv = String.fromEnvironment(
    'DEFAULT_MAP_ZOOM',
    defaultValue: '6.0',
  );

  static const String _minZoomEnv = String.fromEnvironment(
    'MAP_MIN_ZOOM',
    defaultValue: '2.0',
  );

  static const String _maxZoomEnv = String.fromEnvironment(
    'MAP_MAX_ZOOM',
    defaultValue: '19.0',
  );

  /// Configurable application-wide fallback camera coordinates (Priority 3).
  /// Used when device GPS is unavailable/denied (Priority 1) and no contextual
  /// itinerary/destination coordinates exist (Priority 2).
  ///
  /// Defaults to the neutral national geographic centroid of Vietnam (zoom ~6.0)
  /// without hardcoding a fixed city assumption.
  /// Can be configured at build/run time via `--dart-define=DEFAULT_MAP_LATITUDE=<lat>` etc.
  static double get fallbackLatitude =>
      double.tryParse(_defaultLatEnv) ?? neutralCountryCentroidLatitude;

  static double get fallbackLongitude =>
      double.tryParse(_defaultLngEnv) ?? neutralCountryCentroidLongitude;

  static double get fallbackZoom =>
      double.tryParse(_defaultZoomEnv) ?? neutralCountryCentroidZoom;

  /// Default minimum and maximum map zoom bounds.
  static double get minZoom =>
      double.tryParse(_minZoomEnv) ?? 2.0;

  static double get maxZoom =>
      double.tryParse(_maxZoomEnv) ?? 19.0;

  /// Returns the configured fallback camera center as a [LatLng] instance.
  static LatLng get fallbackCoordinates =>
      LatLng(fallbackLatitude, fallbackLongitude);
}
