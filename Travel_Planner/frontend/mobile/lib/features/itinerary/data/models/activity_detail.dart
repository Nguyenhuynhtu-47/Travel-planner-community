import 'destination_summary.dart';

class ActivityDetail {
  final int activityId;
  final String name;
  final String? description;
  final String? activityType;
  final String? startTime;
  final String? endTime;
  final double? estimatedCost;
  final int displayOrder;
  final DestinationSummary? destination;
  final String? customLocationName;
  final String? customAddress;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? locationProvider;
  final String? imageUrl;

  const ActivityDetail({
    required this.activityId,
    required this.name,
    this.description,
    this.activityType,
    this.startTime,
    this.endTime,
    this.estimatedCost,
    required this.displayOrder,
    this.destination,
    this.customLocationName,
    this.customAddress,
    this.latitude,
    this.longitude,
    this.placeId,
    this.locationProvider,
    this.imageUrl,
  });

  factory ActivityDetail.fromJson(Map<String, dynamic> json) {
    // ActivityResponse exposes this field as `cost` in the backend API.
    final rawCost = json['cost'] ?? json['estimatedCost'];
    final rawDest = json['destination'];
    return ActivityDetail(
      activityId: json['activityId'] is num
          ? (json['activityId'] as num).toInt()
          : (int.tryParse(json['activityId']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      activityType: json['activityType']?.toString(),
      startTime: _formatTime(json['startTime']),
      endTime: _formatTime(json['endTime']),
      estimatedCost: rawCost is num
          ? rawCost.toDouble()
          : num.tryParse(rawCost?.toString() ?? '')?.toDouble(),
      displayOrder: json['displayOrder'] is num
          ? (json['displayOrder'] as num).toInt()
          : (int.tryParse(json['displayOrder']?.toString() ?? '') ?? 0),
      destination: rawDest is Map
          ? DestinationSummary.fromJson(Map<String, dynamic>.from(rawDest))
          : null,
      customLocationName: json['customLocationName']?.toString(),
      customAddress: json['customAddress']?.toString(),
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : num.tryParse(json['latitude']?.toString() ?? '')?.toDouble(),
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : num.tryParse(json['longitude']?.toString() ?? '')?.toDouble(),
      placeId: json['placeId']?.toString(),
      locationProvider: json['locationProvider']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  static String? _formatTime(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    // If str is "HH:mm:ss", truncate to "HH:mm"
    if (RegExp(r'^\d{2}:\d{2}:\d{2}').hasMatch(str)) {
      return str.substring(0, 5);
    }
    return str;
  }

  String? get timeRangeFormatted {
    if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    } else if (startTime != null) {
      return startTime;
    } else if (endTime != null) {
      return 'Đến $endTime';
    }
    return null;
  }

  /// Whether the activity has coordinates from either a catalog destination or custom location.
  bool get hasCoordinates =>
      effectiveLatitude != null && effectiveLongitude != null;

  /// Effective latitude: catalog destination coordinates take precedence if present, else custom coordinates.
  double? get effectiveLatitude => destination?.latitude ?? latitude;

  /// Effective longitude: catalog destination coordinates take precedence if present, else custom coordinates.
  double? get effectiveLongitude => destination?.longitude ?? longitude;

  /// Effective display location name: catalog destination name if present, else custom location name.
  String? get effectiveLocationName => destination?.name ?? customLocationName;

  /// Effective display address: catalog destination address if present, else custom address.
  String? get effectiveAddress => destination?.address ?? customAddress;
}
