import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_map_view.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/itinerary_detail.dart';
import 'itinerary_map_helper.dart';

/// Embedded interactive map preview card for [ItineraryDetailScreen].
///
/// Displays activity location markers for the selected itinerary day (or all days),
/// dynamically fits camera bounds, indicates missing coordinates, and provides
/// one-tap access to the full-screen map experience.
class ItineraryMapPreviewCard extends StatefulWidget {
  final ItineraryDetail itinerary;
  final int? selectedDayNumber;
  final VoidCallback? onOpenFullScreen;
  final void Function(ActivityDetail activity)? onActivityTapped;

  const ItineraryMapPreviewCard({
    super.key,
    required this.itinerary,
    this.selectedDayNumber,
    this.onOpenFullScreen,
    this.onActivityTapped,
  });

  @override
  State<ItineraryMapPreviewCard> createState() =>
      _ItineraryMapPreviewCardState();
}

class _ItineraryMapPreviewCardState extends State<ItineraryMapPreviewCard> {
  late final MapController _mapController;
  ActivityDetail? _selectedActivity;
  DateTime? _lastMarkerTappedAt;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant ItineraryMapPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDayNumber != widget.selectedDayNumber ||
        oldWidget.itinerary != widget.itinerary) {
      // Clear stale marker selection on day switch
      if (_selectedActivity != null) {
        setState(() => _selectedActivity = null);
      }
      _adjustCamera();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _adjustCamera() {
    final stops = ItineraryMapHelper.extractMappedStops(
      widget.itinerary,
      selectedDayNumber: widget.selectedDayNumber,
    );

    if (!mounted) return;

    if (stops.isEmpty) {
      _mapController.move(
        MapConstants.fallbackCoordinates,
        MapConstants.fallbackZoom,
      );
    } else if (stops.length == 1) {
      _mapController.move(stops.first.point, 15.0);
    } else {
      final points = stops.map((s) => s.point).toList();
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(32.0),
          maxZoom: 16.0,
        ),
      );
    }
  }

  void _onStopTapped(MappedActivityStop stop) {
    _lastMarkerTappedAt = DateTime.now();
    setState(() {
      _selectedActivity = stop.activity;
    });
    if (widget.onActivityTapped != null) {
      widget.onActivityTapped!(stop.activity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = ItineraryMapHelper.extractMappedStops(
      widget.itinerary,
      selectedDayNumber: widget.selectedDayNumber,
    );

    final totalActivities = ItineraryMapHelper.countTotalActivities(
      widget.itinerary,
      selectedDayNumber: widget.selectedDayNumber,
    );

    final missingNotice = ItineraryMapHelper.getMissingCoordinatesMessage(
      widget.itinerary,
      selectedDayNumber: widget.selectedDayNumber,
    );

    final isMultiDay = widget.selectedDayNumber == null;

    final markers = ItineraryMapHelper.buildActivityMarkers(
      stops: stops,
      isMultiDay: isMultiDay,
      selectedActivity: _selectedActivity,
      onStopTapped: _onStopTapped,
    );

    final points = stops.map((s) => s.point).toList();

    CameraFit? initialCameraFit;
    LatLng? initialCenter;
    double? initialZoom;

    if (points.isEmpty) {
      initialCenter = MapConstants.fallbackCoordinates;
      initialZoom = MapConstants.fallbackZoom;
    } else if (points.length == 1) {
      initialCenter = points.first;
      initialZoom = 15.0;
    } else {
      initialCameraFit = CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(32.0),
        maxZoom: 16.0,
      );
    }

    final headerTitle = widget.selectedDayNumber != null
        ? 'Bản đồ Ngày ${widget.selectedDayNumber}'
        : 'Bản đồ lịch trình';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (stops.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${stops.length} điểm',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onOpenFullScreen != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(
                      Icons.open_in_full,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Toàn màn hình',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: widget.onOpenFullScreen,
                  ),
              ],
            ),
          ),

          // Missing Coordinates Warning Pill (if some or all activities lack coordinates)
          if (missingNotice != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      missingNotice,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Interactive Map Canvas Viewport
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppMapView(
                        mapController: _mapController,
                        initialCenter: initialCenter,
                        initialZoom: initialZoom,
                        initialCameraFit: initialCameraFit,
                        markers: markers,
                        onTap: (_, _) {
                          final lastTap = _lastMarkerTappedAt;
                          if (lastTap != null &&
                              DateTime.now().difference(lastTap).inMilliseconds < 400) {
                            return;
                          }
                          if (_selectedActivity != null) {
                            setState(() => _selectedActivity = null);
                          }
                        },
                      ),
                    ),

                    // Empty Day State Overlay
                    if (totalActivities == 0)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xCCFFFFFF),
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 28,
                                color: AppColors.muted,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Chưa có hoạt động nào trong ngày này',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    // Activities exist but 0 have coordinates Overlay
                    else if (stops.isEmpty)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xCCFFFFFF),
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 28,
                                color: AppColors.muted,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Các hoạt động trong ngày này chưa có vị trí trên bản đồ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Selected Marker Mini Preview Floating Badge
                    if (_selectedActivity != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Material(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.place,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedActivity!.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_selectedActivity!
                                              .effectiveLocationName !=
                                          null)
                                        Text(
                                          _selectedActivity!
                                              .effectiveLocationName!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedActivity = null,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
