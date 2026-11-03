import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_map_view.dart';
import '../../data/models/itinerary_detail.dart';
import '../../data/models/route_models.dart';
import '../../data/route_repository.dart';
import '../widgets/itinerary_map_helper.dart';
import '../widgets/navigation_launcher_helper.dart';

/// Full-screen interactive map screen for exploring itinerary activity locations
/// day-by-day with road route calculation, straight-line Haversine fallback,
/// and free Google Maps navigation deep links.
class ItineraryMapScreen extends StatefulWidget {
  final ItineraryDetail itinerary;
  final int? initialDayNumber;
  final String? token;
  final RouteRepository? routeRepository;
  final UrlLauncherFn? navigationLauncher;

  const ItineraryMapScreen({
    super.key,
    required this.itinerary,
    this.initialDayNumber,
    this.token,
    this.routeRepository,
    this.navigationLauncher,
  });

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  late final MapController _mapController;
  late final RouteRepository _routeRepository;
  int? _selectedDayNumber;
  MappedActivityStop? _selectedStop;
  DateTime? _lastMarkerTappedAt;

  // In-memory cache of routes by dayNumber: Map<int, RouteResponse>
  final Map<int, RouteResponse> _routesByDay = {};
  final Set<int> _loadingDayNumbers = {};
  final Map<int, String> _errorsByDay = {};

  int _routeRequestId = 0;
  String _selectedTravelMode = 'driving';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _routeRepository = widget.routeRepository ?? RouteRepository();
    _selectedDayNumber = widget.initialDayNumber;

    if (_selectedDayNumber != null) {
      _loadRouteForDay(_selectedDayNumber!);
    } else {
      _loadRoutesForAllDays();
    }
  }

  @override
  void didUpdateWidget(covariant ItineraryMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itinerary != widget.itinerary) {
      _routesByDay.clear();
      _errorsByDay.clear();
      _loadingDayNumbers.clear();
      if (_selectedDayNumber != null) {
        _loadRouteForDay(_selectedDayNumber!);
      } else {
        _loadRoutesForAllDays();
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onDaySelected(int? dayNumber) {
    setState(() {
      _selectedDayNumber = dayNumber;
      _selectedStop = null; // Clear stale marker selection
    });
    _recenterCamera();

    if (dayNumber != null) {
      _loadRouteForDay(dayNumber);
    } else {
      _loadRoutesForAllDays();
    }
  }

  void _onTravelModeChanged(String newMode) {
    if (_selectedTravelMode == newMode) return;
    setState(() {
      _selectedTravelMode = newMode;
      _routesByDay.clear();
      _errorsByDay.clear();
      _loadingDayNumbers.clear();
    });

    if (_selectedDayNumber != null) {
      _loadRouteForDay(_selectedDayNumber!);
    } else {
      _loadRoutesForAllDays();
    }
  }

  Future<void> _loadRouteForDay(int dayNumber) async {
    if (_routesByDay.containsKey(dayNumber)) return;

    final day = widget.itinerary.days
        .where((d) => d.dayNumber == dayNumber)
        .firstOrNull;
    if (day == null) return;

    final stops = ItineraryMapHelper.extractMappedStops(
      widget.itinerary,
      selectedDayNumber: dayNumber,
    );

    if (stops.length < 2) {
      setState(() {
        _routesByDay[dayNumber] = RouteResponse(
          itineraryId: widget.itinerary.itineraryId,
          dayId: day.dayId,
          status: 'INSUFFICIENT_WAYPOINTS',
          routeType: 'NONE',
          mode: _selectedTravelMode,
          directDistanceMeters: null,
        );
        _loadingDayNumbers.remove(dayNumber);
        _errorsByDay.remove(dayNumber);
      });
      return;
    }

    final requestId = ++_routeRequestId;
    setState(() {
      _loadingDayNumbers.add(dayNumber);
      _errorsByDay.remove(dayNumber);
    });

    try {
      final route = await _routeRepository.getDayRoute(
        itineraryId: widget.itinerary.itineraryId,
        dayId: day.dayId,
        mode: _selectedTravelMode,
        token: widget.token,
      );

      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _routesByDay[dayNumber] = route;
        _loadingDayNumbers.remove(dayNumber);
        _errorsByDay.remove(dayNumber);
      });

      if (_selectedDayNumber == dayNumber) {
        _recenterCamera();
      }
    } catch (e) {
      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _loadingDayNumbers.remove(dayNumber);
        _errorsByDay[dayNumber] = e.toString();
      });
    }
  }

  Future<void> _loadRoutesForAllDays() async {
    final daysWithStops = widget.itinerary.days.where((day) {
      final stops = ItineraryMapHelper.extractMappedStops(
        widget.itinerary,
        selectedDayNumber: day.dayNumber,
      );
      return stops.length >= 2;
    }).toList();

    for (final day in widget.itinerary.days) {
      if (!daysWithStops.contains(day) && !_routesByDay.containsKey(day.dayNumber)) {
        _routesByDay[day.dayNumber] = RouteResponse(
          itineraryId: widget.itinerary.itineraryId,
          dayId: day.dayId,
          status: 'INSUFFICIENT_WAYPOINTS',
          routeType: 'NONE',
          mode: _selectedTravelMode,
          directDistanceMeters: null,
        );
      }
    }

    final daysToFetch = daysWithStops
        .where((day) => !_routesByDay.containsKey(day.dayNumber))
        .toList();

    if (daysToFetch.isEmpty) return;

    final requestId = ++_routeRequestId;
    setState(() {
      for (final day in daysToFetch) {
        _loadingDayNumbers.add(day.dayNumber);
        _errorsByDay.remove(day.dayNumber);
      }
    });

    await Future.wait(
      daysToFetch.map((day) async {
        try {
          final route = await _routeRepository.getDayRoute(
            itineraryId: widget.itinerary.itineraryId,
            dayId: day.dayId,
            mode: _selectedTravelMode,
            token: widget.token,
          );

          if (!mounted || requestId != _routeRequestId) return;

          setState(() {
            _routesByDay[day.dayNumber] = route;
            _loadingDayNumbers.remove(day.dayNumber);
            _errorsByDay.remove(day.dayNumber);
          });
        } catch (e) {
          if (!mounted || requestId != _routeRequestId) return;

          setState(() {
            _loadingDayNumbers.remove(day.dayNumber);
            _errorsByDay[day.dayNumber] = e.toString();
          });
        }
      }),
    );

    if (mounted && requestId == _routeRequestId && _selectedDayNumber == null) {
      _recenterCamera();
    }
  }

  void _recenterCamera() {
    final stops = ItineraryMapHelper.extractMappedStops(
      widget.itinerary,
      selectedDayNumber: _selectedDayNumber,
    );

    final List<LatLng> targetPoints = stops.map((s) => s.point).toList();

    // Include route geometry points ONLY if actual road route is available
    if (_selectedDayNumber != null) {
      final route = _routesByDay[_selectedDayNumber];
      if (route != null &&
          route.isRoadRoute &&
          route.polylinePoints.isNotEmpty) {
        targetPoints.addAll(route.polylinePoints);
      }
    } else {
      for (final day in widget.itinerary.days) {
        final route = _routesByDay[day.dayNumber];
        if (route != null &&
            route.isRoadRoute &&
            route.polylinePoints.isNotEmpty) {
          targetPoints.addAll(route.polylinePoints);
        }
      }
    }

    if (targetPoints.isEmpty) {
      _mapController.move(
        MapConstants.fallbackCoordinates,
        MapConstants.fallbackZoom,
      );
    } else if (targetPoints.length == 1) {
      _mapController.move(targetPoints.first, 15.0);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: targetPoints,
          padding: const EdgeInsets.fromLTRB(40, 110, 40, 100),
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

    // Build route polyline layers: strictly render a polyline ONLY for actual road routes.
    // Haversine fallback is purely an indicative distance estimate, not a route, so no polyline is drawn.
    final List<Polyline<Object>> polylines = [];
    if (_selectedDayNumber != null) {
      final route = _routesByDay[_selectedDayNumber];
      if (route != null &&
          route.isRoadRoute &&
          route.polylinePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            points: route.polylinePoints,
            color: const Color(0xFF2563EB),
            strokeWidth: 4.5,
          ),
        );
      }
    } else {
      for (final day in widget.itinerary.days) {
        final route = _routesByDay[day.dayNumber];
        if (route != null &&
            route.isRoadRoute &&
            route.polylinePoints.isNotEmpty) {
          polylines.add(
            Polyline(
              points: route.polylinePoints,
              color: ItineraryMapHelper.getDayColor(day.dayNumber),
              strokeWidth: 4.5,
            ),
          );
        }
      }
    }

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
        padding: const EdgeInsets.fromLTRB(40, 110, 40, 100),
        maxZoom: 16.0,
      );
    }

    final showRouteCard = _isRouteCardVisible(stops);

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
          // 1. Full-Screen Interactive Map with Polylines & Markers
          Positioned.fill(
            child: AppMapView(
              mapController: _mapController,
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              initialCameraFit: initialCameraFit,
              markers: markers,
              polylines: polylines,
              apiKeyBannerTopOffset: showRouteCard
                  ? (missingNotice != null ? 142.0 : 108.0)
                  : (missingNotice != null ? 92.0 : 58.0),
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

          // 5. Floating Route Calculation & Navigation Card
          if (showRouteCard)
            Positioned(
              top: missingNotice != null ? 90 : 56,
              left: 14,
              right: 14,
              child: Center(
                child: _buildRouteSummaryCard(stops),
              ),
            ),

          // 6. Selected Activity Bottom Floating Detail Card
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
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ngày ${_selectedStop!.day.dayNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppColors.textSecondary,
                            onPressed: () {
                              setState(() => _selectedStop = null);
                            },
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Location Name / Address
                      if ((_selectedStop!.activity.effectiveLocationName ?? '').isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _selectedStop!.activity.effectiveLocationName!,
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
                        const SizedBox(height: 4),
                      ],

                      // Time & Cost Row
                      Row(
                        children: [
                          if (_selectedStop!.activity.timeRangeFormatted != null) ...[
                            const Icon(
                              Icons.access_time,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedStop!.activity.timeRangeFormatted!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          const Icon(
                            Icons.attach_money,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatCost(_selectedStop!.activity.estimatedCost),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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

  bool _isRouteCardVisible(List<MappedActivityStop> stops) {
    if (stops.isEmpty) return false;
    if (_selectedDayNumber != null) {
      final dayNumber = _selectedDayNumber!;
      if (_loadingDayNumbers.contains(dayNumber)) return true;
      if (_errorsByDay.containsKey(dayNumber)) return true;
      final route = _routesByDay[dayNumber];
      if (route == null) return false;
      return route.isRoadRoute ||
          route.isFallback ||
          (route.isInsufficientWaypoints && stops.length == 1);
    } else {
      if (_loadingDayNumbers.isNotEmpty) return true;
      final hasRoadOrFallback = widget.itinerary.days
          .map((d) => _routesByDay[d.dayNumber])
          .any((r) => r != null && (r.isRoadRoute || r.isFallback));
      if (hasRoadOrFallback) return true;
      if (_errorsByDay.isNotEmpty) return true;
      return stops.length == 1;
    }
  }

  Widget _buildRouteSummaryCard(List<MappedActivityStop> stops) {
    if (_selectedDayNumber != null) {
      final dayNumber = _selectedDayNumber!;
      final isLoading = _loadingDayNumbers.contains(dayNumber);
      final error = _errorsByDay[dayNumber];
      final route = _routesByDay[dayNumber];

      if (isLoading) {
        return Material(
          elevation: 3,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surface,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Đang tính toán tuyến đường...',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (error != null) {
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFFEF2F2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Không thể tải tuyến đường',
                    style: TextStyle(fontSize: 11, color: AppColors.error),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _loadRouteForDay(dayNumber),
                  child: const Text(
                    'Thử lại',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (route == null) {
        return const SizedBox.shrink();
      }

      // Case 1: Road route calculated by routing provider
      if (route.isRoadRoute) {
        return Material(
          elevation: 3,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeIconButton(
                  icon: Icons.directions_car,
                  mode: 'driving',
                  tooltip: 'Lái xe',
                ),
                const SizedBox(width: 2),
                _buildModeIconButton(
                  icon: Icons.directions_walk,
                  mode: 'walking',
                  tooltip: 'Đi bộ',
                ),
                const SizedBox(width: 2),
                _buildModeIconButton(
                  icon: Icons.directions_bike,
                  mode: 'cycling',
                  tooltip: 'Xe đạp',
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Khoảng cách đường bộ: ${route.formattedRoadDistance}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (route.formattedDuration.isNotEmpty)
                        Text(
                          'Thời gian di chuyển: ${route.formattedDuration}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(
                    Icons.navigation,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Chỉ đường',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: () {
                    final wps = stops.map((s) => s.point).toList();
                    NavigationLauncherHelper.launchNavigation(
                      context: context,
                      waypoints: wps,
                      mode: _selectedTravelMode,
                      launcher: widget.navigationLauncher ?? launchUrl,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }

      // Case 2: Haversine straight-line fallback estimate
      if (route.isFallback) {
        return Material(
          elevation: 3,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeIconButton(
                  icon: Icons.directions_car,
                  mode: 'driving',
                  tooltip: 'Lái xe',
                ),
                const SizedBox(width: 2),
                _buildModeIconButton(
                  icon: Icons.directions_walk,
                  mode: 'walking',
                  tooltip: 'Đi bộ',
                ),
                const SizedBox(width: 2),
                _buildModeIconButton(
                  icon: Icons.directions_bike,
                  mode: 'cycling',
                  tooltip: 'Xe đạp',
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Khoảng cách đường chim bay (ước tính): ${route.formattedDirectDistance}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Tuyến đường bộ tạm thời không khả dụng',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB45309),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: const Color(0xFFFEF3C7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(
                    Icons.navigation,
                    size: 12,
                    color: Color(0xFF92400E),
                  ),
                  label: const Text(
                    'Chỉ đường',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  onPressed: () {
                    final wps = stops.map((s) => s.point).toList();
                    NavigationLauncherHelper.launchNavigation(
                      context: context,
                      waypoints: wps,
                      mode: _selectedTravelMode,
                      launcher: widget.navigationLauncher ?? launchUrl,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }

      // Case 3: Single located stop in day
      if (route.isInsufficientWaypoints && stops.length == 1) {
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    '1 điểm dừng có tọa độ',
                    style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(
                    Icons.open_in_new,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Mở Google Maps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: () {
                    final wps = stops.map((s) => s.point).toList();
                    NavigationLauncherHelper.launchNavigation(
                      context: context,
                      waypoints: wps,
                      mode: _selectedTravelMode,
                      launcher: widget.navigationLauncher ?? launchUrl,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }

      return const SizedBox.shrink();
    }

    // Multi-day mode (all days)
    final isLoading = _loadingDayNumbers.isNotEmpty;
    if (isLoading) {
      return Material(
        elevation: 3,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surface,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Đang tính toán tuyến đường...',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final roadRoutes = widget.itinerary.days
        .map((d) => _routesByDay[d.dayNumber])
        .where((r) => r != null && r.isRoadRoute)
        .cast<RouteResponse>()
        .toList();

    final fallbackRoutes = widget.itinerary.days
        .map((d) => _routesByDay[d.dayNumber])
        .where((r) => r != null && r.isFallback)
        .cast<RouteResponse>()
        .toList();

    if (roadRoutes.isNotEmpty) {
      final totalDistanceMeters = roadRoutes.fold<double>(
        0.0,
        (sum, r) => sum + (r.totalDistanceMeters ?? 0.0),
      );
      final totalDurationSeconds = roadRoutes.fold<double>(
        0.0,
        (sum, r) => sum + (r.totalDurationSeconds ?? 0.0),
      );

      final totalDaysWithStops = widget.itinerary.days
          .where((d) => d.activities.any((a) => a.hasCoordinates))
          .length;
      final isPartial = roadRoutes.length < totalDaysWithStops;

      return Material(
        elevation: 3,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeIconButton(
                icon: Icons.directions_car,
                mode: 'driving',
                tooltip: 'Lái xe',
              ),
              const SizedBox(width: 2),
              _buildModeIconButton(
                icon: Icons.directions_walk,
                mode: 'walking',
                tooltip: 'Đi bộ',
              ),
              const SizedBox(width: 2),
              _buildModeIconButton(
                icon: Icons.directions_bike,
                mode: 'cycling',
                tooltip: 'Xe đạp',
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Khoảng cách đường bộ: ${RouteResponse.formatDistance(totalDistanceMeters)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (totalDurationSeconds > 0)
                      Text(
                        isPartial
                            ? 'Thời gian di chuyển: ${RouteResponse.formatDuration(totalDurationSeconds)} (${roadRoutes.length}/$totalDaysWithStops ngày)'
                            : 'Thời gian di chuyển: ${RouteResponse.formatDuration(totalDurationSeconds)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(
                  Icons.navigation,
                  size: 12,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Chỉ đường',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                onPressed: () {
                  final wps = stops.map((s) => s.point).toList();
                  NavigationLauncherHelper.launchNavigation(
                    context: context,
                    waypoints: wps,
                    mode: _selectedTravelMode,
                    launcher: widget.navigationLauncher ?? launchUrl,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    if (roadRoutes.isEmpty && fallbackRoutes.isNotEmpty) {
      final totalDirectMeters = fallbackRoutes.fold<double>(
        0.0,
        (sum, r) => sum + (r.directDistanceMeters ?? 0.0),
      );

      return Material(
        elevation: 3,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFEF3C7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeIconButton(
                icon: Icons.directions_car,
                mode: 'driving',
                tooltip: 'Lái xe',
              ),
              const SizedBox(width: 2),
              _buildModeIconButton(
                icon: Icons.directions_walk,
                mode: 'walking',
                tooltip: 'Đi bộ',
              ),
              const SizedBox(width: 2),
              _buildModeIconButton(
                icon: Icons.directions_bike,
                mode: 'cycling',
                tooltip: 'Xe đạp',
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Khoảng cách đường chim bay (ước tính): ${RouteResponse.formatDistance(totalDirectMeters)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Tuyến đường bộ tạm thời không khả dụng',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFB45309),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: const Color(0xFFFEF3C7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(
                  Icons.navigation,
                  size: 12,
                  color: Color(0xFF92400E),
                ),
                label: const Text(
                  'Chỉ đường',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                onPressed: () {
                  final wps = stops.map((s) => s.point).toList();
                  NavigationLauncherHelper.launchNavigation(
                    context: context,
                    waypoints: wps,
                    mode: _selectedTravelMode,
                    launcher: widget.navigationLauncher ?? launchUrl,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_errorsByDay.isNotEmpty && roadRoutes.isEmpty) {
      return Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFEF2F2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'Không thể tải tuyến đường',
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _loadRoutesForAllDays,
                child: const Text(
                  'Thử lại',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (stops.length == 1) {
      return Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  '1 điểm dừng có tọa độ',
                  style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Mở Google Maps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                onPressed: () {
                  final wps = stops.map((s) => s.point).toList();
                  NavigationLauncherHelper.launchNavigation(
                    context: context,
                    waypoints: wps,
                    mode: _selectedTravelMode,
                    launcher: widget.navigationLauncher ?? launchUrl,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildModeIconButton({
    required IconData icon,
    required String mode,
    required String tooltip,
  }) {
    final isSelected = _selectedTravelMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _onTravelModeChanged(mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1)
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.hairline,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withAlpha(50) : Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
