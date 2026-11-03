import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/map_constants.dart';
import '../../core/constants/map_tile_provider_config.dart';
import 'map_api_key_missing_banner.dart';

/// Base reusable map widget for Flutter mobile.
///
/// Wraps [FlutterMap] with standardized tile provider configuration,
/// neutral configurable fallback camera coordinates, and mandatory tile attribution.
///
/// ### Camera Centering Priority Hierarchy:
/// 1. **Priority 1 (User Current Location):** When GPS coordinates are acquired,
///    caller supplies [initialCenter] (user's GPS position) and [initialZoom] (~14.0).
/// 2. **Priority 2 (Contextual Coordinates / Bounds):** When viewing an itinerary day
///    or destination preview, caller supplies [initialCameraFit] (e.g. `CameraFit.bounds(...)`)
///    or [initialCenter] (destination point), which takes precedence to frame all active stops.
/// 3. **Priority 3 (Configurable Application-Wide Fallback):** When neither GPS nor
///    contextual coordinates are available, camera centers on the neutral national geographic
///    centroid of Vietnam ([MapConstants.fallbackCoordinates] at [MapConstants.fallbackZoom]),
///    avoiding assuming any single fixed city as default.
///
/// ### Mandatory Tile Attribution:
/// For providers requiring attribution (e.g., CARTO Basemaps and OpenStreetMap where
/// [MapTileProviderConfig.requiresAttribution] is `true`), attribution is strictly preserved
/// to prevent accidental license violations during normal screen usage.
/// Setting [showAttribution] to `false` will only omit attribution if the provider does not
/// require it or if an alternative [customAttributionWidget] is provided.
class AppBaseMap extends StatelessWidget {
  /// Tile provider configuration, decoupled from map UI.
  /// Defaults to [MapTileProviderConfig.defaultProvider] (CARTO Basemaps Voyager).
  final MapTileProviderConfig tileProviderConfig;

  /// Priority 2 camera fit: visible bounds or coordinates to fit on screen.
  /// When provided, takes precedence over [initialCenter] and [initialZoom]
  /// to frame all active stops or destination areas.
  final CameraFit? initialCameraFit;

  /// Priority 1 (GPS) or Priority 2 (Contextual Point) camera center.
  /// Defaults to [MapConstants.fallbackCoordinates] (Priority 3 neutral country centroid)
  /// when neither GPS nor contextual bounds/coordinates are provided.
  final LatLng? initialCenter;

  /// Initial camera zoom. Defaults to [MapConstants.fallbackZoom].
  final double? initialZoom;

  /// Optional controller to programmatically move, rotate, or inspect the map.
  final MapController? mapController;

  /// Additional layers (e.g., markers, polylines, overlays) rendered above tiles.
  final List<Widget> children;

  /// Callback when a user taps on the map canvas.
  final void Function(TapPosition tapPosition, LatLng point)? onTap;

  /// Callback when a user long-presses on the map canvas.
  final void Function(TapPosition tapPosition, LatLng point)? onLongPress;

  /// Callback when camera position changes (panning, zooming, rotating).
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;

  /// Gesture and interaction options (pinch to zoom, drag to pan, etc.).
  final InteractionOptions? interactionOptions;

  /// Whether to display the tile provider attribution widget.
  ///
  /// Safe Design: When using tile providers that legally mandate attribution
  /// (such as CARTO Basemaps or OpenStreetMap where [MapTileProviderConfig.requiresAttribution] is true),
  /// setting this to `false` will NOT hide required attribution unless an alternative
  /// [customAttributionWidget] is provided. This prevents accidental licensing violations
  /// during normal screen development while remaining configurable for private/self-hosted providers.
  final bool showAttribution;

  /// Optional custom attribution widget if a screen renders custom attribution UI.
  /// When provided, replaces the default [RichAttributionWidget].
  final Widget? customAttributionWidget;

  /// Optional callback invoked when the attribution widget is tapped.
  final VoidCallback? onAttributionTap;

  /// Alignment of the attribution badge on the map canvas.
  /// Allows screens with bottom-right floating action buttons to position
  /// attribution at [AttributionAlignment.bottomLeft] without hiding it.
  final AttributionAlignment attributionAlignment;

  /// Whether to display a warning/instruction banner if the tile provider
  /// mandates an API key (CARTO Basemaps) and none is configured.
  final bool showApiKeyMissingBanner;

  /// Top offset for positioning the missing API key guidance banner.
  /// Allows screens with floating top bars (e.g. day selector) to avoid overlap.
  final double apiKeyBannerTopOffset;

  /// Optional custom banner widget replacing the default [MapApiKeyMissingBanner].
  final Widget? customApiKeyMissingBanner;

  AppBaseMap({
    super.key,
    MapTileProviderConfig? tileProviderConfig,
    this.initialCameraFit,
    this.initialCenter,
    this.initialZoom,
    this.mapController,
    this.children = const [],
    this.onTap,
    this.onLongPress,
    this.onPositionChanged,
    this.interactionOptions,
    this.showAttribution = true,
    this.customAttributionWidget,
    this.onAttributionTap,
    this.attributionAlignment = AttributionAlignment.bottomRight,
    this.showApiKeyMissingBanner = true,
    this.apiKeyBannerTopOffset = 12.0,
    this.customApiKeyMissingBanner,
  }) : tileProviderConfig =
            tileProviderConfig ?? MapTileProviderConfig.defaultProvider();

  bool get _shouldRenderAttribution {
    if (customAttributionWidget != null) return true;
    if (tileProviderConfig.requiresAttribution) return true;
    return showAttribution;
  }

  Widget _buildAttributionLayer() {
    if (customAttributionWidget != null) {
      return customAttributionWidget!;
    }
    return tileProviderConfig.buildAttributionWidget(
      onAttributionTap: onAttributionTap,
      alignment: attributionAlignment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCenter = initialCenter ?? MapConstants.fallbackCoordinates;
    final effectiveZoom = initialZoom ?? MapConstants.fallbackZoom;

    final mapWidget = FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCameraFit: initialCameraFit,
        initialCenter: effectiveCenter,
        initialZoom: effectiveZoom,
        minZoom: tileProviderConfig.minZoom,
        maxZoom: tileProviderConfig.maxZoom,
        onTap: onTap,
        onLongPress: onLongPress,
        onPositionChanged: onPositionChanged,
        interactionOptions: interactionOptions ??
            const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
      ),
      children: [
        tileProviderConfig.buildTileLayer(),
        ...children,
        if (_shouldRenderAttribution)
          _buildAttributionLayer(),
      ],
    );

    if (!showApiKeyMissingBanner || !tileProviderConfig.isApiKeyMissing) {
      return mapWidget;
    }

    return Stack(
      children: [
        Positioned.fill(child: mapWidget),
        Positioned(
          top: apiKeyBannerTopOffset,
          left: 0,
          right: 0,
          child: customApiKeyMissingBanner ?? const MapApiKeyMissingBanner(),
        ),
      ],
    );
  }
}
