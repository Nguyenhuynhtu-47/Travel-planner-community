import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/map_constants.dart';
import '../../core/constants/map_tile_provider_config.dart';
import 'app_base_map.dart';

export '../../core/constants/map_constants.dart';
export '../../core/constants/map_tile_provider_config.dart';
export 'app_base_map.dart';
export 'map_marker_builder.dart';

/// Reusable, memory-efficient Flutter map wrapper for mobile screens.
///
/// Refines and extends [AppBaseMap] by providing first-class support for
/// marker overlays ([markers]), polyline routes ([polylines]), and custom layers ([children]),
/// while preserving the Phase 0 camera hierarchy and mandatory CARTO/OSM tile attribution.
///
/// ### Layer Order:
/// 1. Tile Layer (CARTO Voyager tiles from CDN via [tileProviderConfig]).
/// 2. Polyline Layer (when [polylines] are provided, rendered beneath markers).
/// 3. Marker Layer (when [markers] are provided).
/// 4. Custom child layers (e.g. polygon layers, interactive overlays).
/// 5. Mandatory Attribution Layer ([RichAttributionWidget]).
///
/// ### Lifecycle and Memory Safety:
/// - [AppMapView] is a stateless widget that manages no persistent listeners or streams.
/// - If [mapController] is provided by the caller, the caller is responsible for disposing it.
///   If [mapController] is omitted, [FlutterMap] internally manages its own controller.
class AppMapView extends StatelessWidget {
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

  /// Initial camera zoom level. Defaults to [MapConstants.fallbackZoom].
  final double? initialZoom;

  /// Optional controller to programmatically move, rotate, or inspect the map.
  final MapController? mapController;

  /// Markers to render on the map. Automatically wrapped in a [MarkerLayer].
  final List<Marker>? markers;

  /// Polylines to render on the map. Automatically wrapped in a [PolylineLayer].
  final List<Polyline<Object>>? polylines;

  /// Additional custom layers rendered above polylines and markers.
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
  /// Note: When [MapTileProviderConfig.requiresAttribution] is `true`,
  /// attribution is safely preserved and cannot be accidentally hidden.
  final bool showAttribution;

  /// Optional custom attribution widget if a screen renders custom attribution UI.
  final Widget? customAttributionWidget;

  /// Optional callback invoked when the attribution widget is tapped.
  final VoidCallback? onAttributionTap;

  /// Alignment of the attribution badge on the map canvas.
  final AttributionAlignment attributionAlignment;

  AppMapView({
    super.key,
    MapTileProviderConfig? tileProviderConfig,
    this.initialCameraFit,
    this.initialCenter,
    this.initialZoom,
    this.mapController,
    this.markers,
    this.polylines,
    this.children = const [],
    this.onTap,
    this.onLongPress,
    this.onPositionChanged,
    this.interactionOptions,
    this.showAttribution = true,
    this.customAttributionWidget,
    this.onAttributionTap,
    this.attributionAlignment = AttributionAlignment.bottomRight,
  }) : tileProviderConfig =
            tileProviderConfig ?? MapTileProviderConfig.defaultProvider();

  @override
  Widget build(BuildContext context) {
    return AppBaseMap(
      tileProviderConfig: tileProviderConfig,
      initialCameraFit: initialCameraFit,
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      mapController: mapController,
      onTap: onTap,
      onLongPress: onLongPress,
      onPositionChanged: onPositionChanged,
      interactionOptions: interactionOptions,
      showAttribution: showAttribution,
      customAttributionWidget: customAttributionWidget,
      onAttributionTap: onAttributionTap,
      attributionAlignment: attributionAlignment,
      children: [
        if (polylines != null && polylines!.isNotEmpty)
          PolylineLayer<Object>(polylines: polylines!),
        if (markers != null && markers!.isNotEmpty)
          MarkerLayer(markers: markers!),
        ...children,
      ],
    );
  }
}
