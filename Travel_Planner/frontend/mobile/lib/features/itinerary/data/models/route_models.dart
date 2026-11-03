import 'package:latlong2/latlong.dart';

/// Waypoint participating in route calculation.
class RouteWaypoint {
  final int activityId;
  final String name;
  final String? locationName;
  final double latitude;
  final double longitude;
  final int displayOrder;

  const RouteWaypoint({
    required this.activityId,
    required this.name,
    this.locationName,
    required this.latitude,
    required this.longitude,
    required this.displayOrder,
  });

  LatLng get point => LatLng(latitude, longitude);

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    return RouteWaypoint(
      activityId: (json['activityId'] as num).toInt(),
      name: json['name'] as String? ?? '',
      locationName: json['locationName'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activityId': activityId,
      'name': name,
      if (locationName != null) 'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'displayOrder': displayOrder,
    };
  }
}

/// Normalized per-day route calculation API response model.
class RouteResponse {
  final int itineraryId;
  final int dayId;
  final String status;
  final String routeType;
  final String mode;
  final double? totalDistanceMeters;
  final double? directDistanceMeters;
  final double? totalDurationSeconds;
  final List<RouteWaypoint> waypoints;
  final List<List<double>> geometryCoordinates;

  const RouteResponse({
    required this.itineraryId,
    required this.dayId,
    required this.status,
    required this.routeType,
    required this.mode,
    this.totalDistanceMeters,
    this.directDistanceMeters,
    this.totalDurationSeconds,
    this.waypoints = const [],
    this.geometryCoordinates = const [],
  });

  /// Whether a verified road route from the routing provider is available.
  bool get isRoadRoute =>
      status == 'SUCCESS' && routeType == 'ACTUAL_ROAD';

  /// Whether the route is an approximate straight-line Haversine estimate.
  bool get isFallback =>
      status == 'FALLBACK' || routeType == 'ESTIMATED_INDICATIVE';

  /// Whether the day has fewer than 2 located stops.
  bool get isInsufficientWaypoints =>
      status == 'INSUFFICIENT_WAYPOINTS' || routeType == 'NONE';

  /// Converts GeoJSON `[longitude, latitude]` pairs into Flutter [LatLng].
  List<LatLng> get polylinePoints {
    return geometryCoordinates
        .where((coord) => coord.length >= 2)
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();
  }

  /// Formats road distance into user-friendly Vietnamese notation.
  String get formattedRoadDistance {
    if (totalDistanceMeters == null) return '';
    return formatDistance(totalDistanceMeters!);
  }

  /// Formats straight-line Haversine distance into user-friendly Vietnamese notation.
  String get formattedDirectDistance {
    if (directDistanceMeters == null) return '';
    return formatDistance(directDistanceMeters!);
  }

  /// Formats estimated duration into user-friendly Vietnamese notation (hours and minutes).
  String get formattedDuration {
    if (totalDurationSeconds == null) return '';
    return formatDuration(totalDurationSeconds!);
  }

  static String formatDuration(double totalDurationSeconds) {
    final totalMinutes = (totalDurationSeconds / 60.0).round();
    if (totalMinutes < 1) return '< 1 phút';
    if (totalMinutes < 60) return '$totalMinutes phút';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins == 0 ? '$hours giờ' : '$hours giờ $mins phút';
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.toStringAsFixed(0)} km';
  }

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    final rawWaypoints = json['waypoints'] as List<dynamic>? ?? [];
    final waypoints = rawWaypoints
        .map((e) => RouteWaypoint.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawGeometry = json['geometryCoordinates'] as List<dynamic>? ?? [];
    final geometryCoordinates = rawGeometry.map((item) {
      final list = item as List<dynamic>;
      return list.map((numVal) => (numVal as num).toDouble()).toList();
    }).toList();

    return RouteResponse(
      itineraryId: (json['itineraryId'] as num).toInt(),
      dayId: (json['dayId'] as num).toInt(),
      status: json['status'] as String? ?? 'UNKNOWN',
      routeType: json['routeType'] as String? ?? 'NONE',
      mode: json['mode'] as String? ?? 'driving',
      totalDistanceMeters: (json['totalDistanceMeters'] as num?)?.toDouble(),
      directDistanceMeters:
          (json['directDistanceMeters'] as num?)?.toDouble(),
      totalDurationSeconds:
          (json['totalDurationSeconds'] as num?)?.toDouble(),
      waypoints: waypoints,
      geometryCoordinates: geometryCoordinates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itineraryId': itineraryId,
      'dayId': dayId,
      'status': status,
      'routeType': routeType,
      'mode': mode,
      'totalDistanceMeters': totalDistanceMeters,
      'directDistanceMeters': directDistanceMeters,
      'totalDurationSeconds': totalDurationSeconds,
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'geometryCoordinates': geometryCoordinates,
    };
  }
}

