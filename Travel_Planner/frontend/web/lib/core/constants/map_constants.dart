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

