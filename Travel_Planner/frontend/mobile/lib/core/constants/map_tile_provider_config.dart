import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_constants.dart';

/// Configuration definition for map tile providers.
///
/// Decouples tile source specification (URLs, subdomains, attribution, zoom limits, headers)
/// from map presentation widgets (`AppBaseMap`). Allows switching providers (e.g., CARTO,
/// MapTiler, self-hosted tile servers) without rewriting any UI layer or map widgets.
class MapTileProviderConfig {
  /// URL template for the raster tile server, e.g.
  /// `https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png`.
  final String urlTemplate;

  /// Required attribution text honoring tile licensing terms.
  final String attribution;

  /// Whether this tile provider legally mandates attribution visibility
  /// (e.g., CARTO Basemaps and OpenStreetMap under ODbL require attribution).
  ///
  /// When `true`, [AppBaseMap] safely preserves attribution and prevents it
  /// from being silently dropped by normal screen usage.
  final bool requiresAttribution;

  /// Subdomains used for load balancing requests across CDN edges.
  final List<String> subdomains;

  /// Package name forwarded in User-Agent header when permitted.
  final String userAgentPackageName;

  /// Minimum zoom level for which tiles should be requested.
  final double minZoom;

  /// Maximum zoom level for which tiles should be requested.
  final double maxZoom;

  /// Additional template parameters for substitution into [urlTemplate].
  final Map<String, String> additionalOptions;

  /// Optional HTTP headers sent with tile requests (used on platforms that support custom headers).
  final Map<String, String>? headers;

  /// Custom [TileProvider] implementation, defaulting to [NetworkTileProvider].
  final TileProvider? tileProvider;

  /// Whether to suppress network tile fetch exceptions and render transparent/error tile fallback gracefully.
  final bool silenceExceptions;

  const MapTileProviderConfig({
    required this.urlTemplate,
    required this.attribution,
    this.requiresAttribution = true,
    this.subdomains = MapConstants.defaultSubdomains,
    this.userAgentPackageName = MapConstants.userAgentPackageName,
    this.minZoom = 2.0,
    this.maxZoom = 19.0,
    this.additionalOptions = const {},
    this.headers,
    this.tileProvider,
    this.silenceExceptions = true,
  });

  /// Creates a configuration using the application's default settings from [MapConstants] (CARTO Basemaps Voyager).
  factory MapTileProviderConfig.defaultProvider({
    bool silenceExceptions = true,
  }) {
    return MapTileProviderConfig(
      urlTemplate: MapConstants.tileUrlTemplate,
      attribution: MapConstants.tileAttribution,
      requiresAttribution: true,
      subdomains: MapConstants.defaultSubdomains,
      userAgentPackageName: MapConstants.userAgentPackageName,
      minZoom: MapConstants.minZoom,
      maxZoom: MapConstants.maxZoom,
      silenceExceptions: silenceExceptions,
    );
  }

  /// Creates a CARTO Basemaps configuration for a specified flavor (`voyager`, `positron`, `dark_all`).
  factory MapTileProviderConfig.carto({
    String flavor = 'voyager',
    bool silenceExceptions = true,
  }) {
    return MapTileProviderConfig(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/rastertiles/$flavor/{z}/{x}/{y}{r}.png',
      attribution: '© OpenStreetMap contributors, © CARTO',
      requiresAttribution: true,
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: MapConstants.userAgentPackageName,
      minZoom: MapConstants.minZoom,
      maxZoom: MapConstants.maxZoom,
      silenceExceptions: silenceExceptions,
    );
  }

  /// Creates an OpenStreetMap configuration restricted strictly to manual local development.
  /// Note: Not for production use per OSM Foundation Tile Usage Policy.
  factory MapTileProviderConfig.openStreetMapDev({
    bool silenceExceptions = true,
  }) {
    return MapTileProviderConfig(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
      requiresAttribution: true,
      subdomains: const [],
      userAgentPackageName: MapConstants.userAgentPackageName,
      minZoom: 2.0,
      maxZoom: 19.0,
      silenceExceptions: silenceExceptions,
    );
  }

  /// Builds a [TileLayer] configured according to this specification.
  TileLayer buildTileLayer({
    TileDisplay? tileDisplay,
    ErrorTileCallBack? errorTileCallback,
    ImageProvider? errorImage,
    bool? retinaMode,
  }) {
    return TileLayer(
      urlTemplate: urlTemplate,
      subdomains: subdomains,
      userAgentPackageName: userAgentPackageName,
      minZoom: minZoom,
      maxZoom: maxZoom,
      additionalOptions: additionalOptions,
      retinaMode: retinaMode ?? urlTemplate.contains('{r}'),
      tileProvider: tileProvider ??
          NetworkTileProvider(
            headers:
                headers != null ? Map<String, String>.from(headers!) : null,
            silenceExceptions: silenceExceptions,
          ),
      tileDisplay: tileDisplay ?? const TileDisplay.fadeIn(),
      errorTileCallback: errorTileCallback,
      errorImage: errorImage,
    );
  }

  /// Builds the attribution overlay widget for this tile provider.
  /// If attribution is empty, returns an empty [SizedBox].
  Widget buildAttributionWidget({
    VoidCallback? onAttributionTap,
    AttributionAlignment alignment = AttributionAlignment.bottomRight,
  }) {
    if (attribution.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return RichAttributionWidget(
      alignment: alignment,
      attributions: [
        TextSourceAttribution(
          attribution,
          onTap: onAttributionTap,
        ),
      ],
    );
  }
}
