import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_map_view.dart';
import '../../data/models/itinerary_detail.dart';
import '../widgets/itinerary_map_helper.dart';

/// Full-screen interactive map screen for exploring itinerary activity locations
/// day-by-day.
class ItineraryMapScreen extends StatefulWidget {
  final ItineraryDetail itinerary;
  final int? initialDayNumber;

  const ItineraryMapScreen({
    super.key,
    required this.itinerary,
    this.initialDayNumber,
  });

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  late final MapController _mapController;
  int? _selectedDayNumber;
  MappedActivityStop? _selectedStop;
  DateTime? _lastMarkerTappedAt;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedDayNumber = widget.initialDayNumber;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onDaySelected(int? dayNumber) {
    setState(() {
      _selectedDayNumber = dayNumber;
      _selectedStop = null; // Clear stale selection on day change
    });
    _recenterCamera();
  }

  void _recenterCamera() {
    final stops = ItineraryMapHelper.extractMappedStops(
      widget.itinerary,
      selectedDayNumber: _selectedDayNumber,
    );

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
          padding: const EdgeInsets.fromLTRB(40, 90, 40, 100),
          maxZoom: 16.0,
        ),
      );
    }
  }

  void _onStopTapped(MappedActivityStop stop) {
    _lastMarkerTappedAt = DateTime.now();
    setState(() {
      _selectedStop = stop;
    });
    _mapController.move(stop.point, 15.5);
  }

  String _formatCost(double? cost) {
    if (cost == null || cost <= 0) return 'Miễn phí';
    final formatted = cost.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }

  @override
  Widget build(BuildContext context) {
    final stops = ItineraryMapHelper.extractMappedStops(
      widget.itinerary,
      selectedDayNumber: _selectedDayNumber,
    );

    final totalActivities = ItineraryMapHelper.countTotalActivities(
      widget.itinerary,
      selectedDayNumber: _selectedDayNumber,
    );

    final missingNotice = ItineraryMapHelper.getMissingCoordinatesMessage(
      widget.itinerary,
      selectedDayNumber: _selectedDayNumber,
    );

    final isMultiDay = _selectedDayNumber == null;

    final markers = ItineraryMapHelper.buildActivityMarkers(
      stops: stops,
      isMultiDay: isMultiDay,
      selectedActivity: _selectedStop?.activity,
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
        padding: const EdgeInsets.fromLTRB(40, 90, 40, 100),
        maxZoom: 16.0,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.itinerary.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.itinerary.location.isNotEmpty
                  ? '${widget.itinerary.location} • Bản đồ lịch trình'
                  : 'Bản đồ lịch trình',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong_outlined),
            tooltip: 'Căn giữa các điểm',
            onPressed: stops.isNotEmpty ? _recenterCamera : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full-Screen Interactive Map
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
                if (_selectedStop != null) {
                  setState(() => _selectedStop = null);
                }
              },
            ),
          ),

          // 2. Empty Day Overlays (Beneath floating controls so day selector remains tappable)
          if (totalActivities == 0)
            Positioned.fill(
              child: Container(
                color: const Color(0xB3FFFFFF),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 36,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có hoạt động nào trong ngày này',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (stops.isEmpty)
            Positioned.fill(
              child: Container(
                color: const Color(0xB3FFFFFF),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 36,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Các hoạt động trong ngày này chưa có vị trí trên bản đồ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // 3. Top Floating Day Selector Bar
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _buildDayChip(
                    label: 'Tất cả (${widget.itinerary.days.length})',
                    isSelected: _selectedDayNumber == null,
                    color: AppColors.primary,
                    onSelected: () => _onDaySelected(null),
                  ),
                  const SizedBox(width: 6),
                  for (final day in widget.itinerary.days) ...[
                    _buildDayChip(
                      label: 'Ngày ${day.dayNumber} (${day.activities.length})',
                      isSelected: _selectedDayNumber == day.dayNumber,
                      color: ItineraryMapHelper.getDayColor(day.dayNumber),
                      onSelected: () => _onDaySelected(day.dayNumber),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),

          // 4. Top Floating Missing Coordinates Notice Pill
          if (missingNotice != null)
            Positioned(
              top: 56,
              left: 14,
              right: 14,
              child: Center(
                child: Material(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFFFFBEB),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            missingNotice,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 5. Selected Activity Bottom Floating Detail Card
          if (_selectedStop != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: Material(
                elevation: 6,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge Row + Close Button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Điểm #${_selectedStop!.sequence}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ItineraryMapHelper.getDayColor(
                                _selectedStop!.day.dayNumber,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ngày ${_selectedStop!.day.dayNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ItineraryMapHelper.getDayColor(
                                  _selectedStop!.day.dayNumber,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _selectedStop = null),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Activity Title
                      Text(
                        _selectedStop!.activity.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      // Location & Address
                      if (_selectedStop!.activity.effectiveLocationName !=
                              null ||
                          _selectedStop!.activity.effectiveAddress != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _selectedStop!.activity.effectiveLocationName ??
                                    _selectedStop!
                                        .activity
                                        .effectiveAddress!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Time & Cost row
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_selectedStop!.activity.timeRangeFormatted !=
                              null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedStop!.activity.timeRangeFormatted!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Text(
                              _formatCost(
                                _selectedStop!.activity.estimatedCost,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildDayChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return Material(
      elevation: isSelected ? 3 : 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      color: isSelected ? color : AppColors.surface,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
