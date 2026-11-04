import 'package:latlong2/latlong.dart';

/// Centralized configuration and constants for map rendering,
/// free tile CDN endpoints, attribution notices, and camera defaults for Flutter Web.
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
  static const String tileAttribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors, © CARTO',
  );

  /// Tile server subdomains used for round-robin load distribution.
  static const List<String> defaultSubdomains = ['a', 'b', 'c', 'd'];

  /// Package identifier sent in tile requests' User-Agent header where permitted.
  static const String userAgentPackageName = 'com.travelplanner.web';

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
  /// Provides an unbiased, country-wide overview without favoring any specific city.
  static const double neutralCountryCentroidLatitude = 14.0583;
  static const double neutralCountryCentroidLongitude = 108.2772;
  static const double neutralCountryCentroidZoom = 6.0;

  static LatLng get fallbackCoordinates => const LatLng(
        neutralCountryCentroidLatitude,
        neutralCountryCentroidLongitude,
      );

  static const double fallbackZoom = neutralCountryCentroidZoom;
}

