import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/map_constants.dart';
import '../../core/theme/app_colors.dart';

/// Reusable interactive map widget for Flutter Web.
///
/// Embeds CARTO Basemaps (Voyager) with mandatory attribution, supports custom markers,
/// pin-dropping through tap callbacks, and responsive map controls.
class WebMapView extends StatefulWidget {
  final MapController? mapController;
  final LatLng? initialCenter;
  final double? initialZoom;
  final CameraFit? initialCameraFit;
  final List<Marker> markers;
  final void Function(TapPosition tapPosition, LatLng point)? onTap;
  final bool showAttribution;
  final bool showControls;

  const WebMapView({
    super.key,
    this.mapController,
    this.initialCenter,
    this.initialZoom,
    this.initialCameraFit,
    this.markers = const [],
    this.onTap,
    this.showAttribution = true,
    this.showControls = true,
  });

  @override
  State<WebMapView> createState() => _WebMapViewState();
}

class _WebMapViewState extends State<WebMapView> {
  late final MapController _effectiveController;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.mapController ?? MapController();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter ?? MapConstants.fallbackCoordinates;
    final zoom = widget.initialZoom ?? MapConstants.fallbackZoom;

    return Stack(
      children: [
        // 1. FlutterMap Tile & Marker Canvas
        FlutterMap(
          mapController: _effectiveController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            initialCameraFit: widget.initialCameraFit,
            onTap: widget.onTap,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // CARTO Basemaps Layer
            TileLayer(
              urlTemplate: MapConstants.tileUrlTemplate,
              subdomains: MapConstants.defaultSubdomains,
              userAgentPackageName: MapConstants.userAgentPackageName,
              maxZoom: 19,
              retinaMode: RetinaMode.isHighDensity(context),
              errorTileCallback: (tile, error, stackTrace) {
                // Non-blocking tile error handling
              },
            ),

            // Markers Layer
            if (widget.markers.isNotEmpty)
              MarkerLayer(markers: widget.markers),
          ],
        ),

        // 2. Zoom & Recenter Controls
        if (widget.showControls)
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Phóng to',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final currentZoom = _effectiveController.camera.zoom;
                      _effectiveController.move(
                        _effectiveController.camera.center,
                        (currentZoom + 1).clamp(2.0, 19.0),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.hairline),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    tooltip: 'Thu nhỏ',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final currentZoom = _effectiveController.camera.zoom;
                      _effectiveController.move(
                        _effectiveController.camera.center,
                        (currentZoom - 1).clamp(2.0, 19.0),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

        // 3. Mandatory Attribution Pill (CARTO & OpenStreetMap)
        if (widget.showAttribution)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
              child: const Text(
                MapConstants.tileAttribution,
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
