import 'destination_summary.dart';
import 'place_summary.dart';

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
  final int? canonicalPlaceId;
  final PlaceSummary? place;
  final String? locationName;
  final String? locationAddress;
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
    this.canonicalPlaceId,
    this.place,
    this.locationName,
    this.locationAddress,
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
    final rawPlace = json['place'];
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
      canonicalPlaceId: json['canonicalPlaceId'] is num
          ? (json['canonicalPlaceId'] as num).toInt()
          : (int.tryParse(json['canonicalPlaceId']?.toString() ?? '')),
      place: rawPlace is Map
          ? PlaceSummary.fromJson(Map<String, dynamic>.from(rawPlace))
          : null,
      locationName: (json['locationName'] ?? json['customLocationName'])?.toString(),
      locationAddress: (json['locationAddress'] ?? json['customAddress'])?.toString(),
      customLocationName: (json['customLocationName'] ?? json['locationName'])?.toString(),
      customAddress: (json['customAddress'] ?? json['locationAddress'])?.toString(),
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

  /// Whether the activity has coordinates from its snapshot.
  bool get hasCoordinates =>
      effectiveLatitude != null && effectiveLongitude != null;

  /// Authoritative latitude: strictly from activity snapshot coordinates.
  double? get effectiveLatitude => latitude;

  /// Authoritative longitude: strictly from activity snapshot coordinates.
  double? get effectiveLongitude => longitude;

  /// Authoritative display location name: strictly from activity snapshot
  /// (locationName takes precedence, falling back to legacy customLocationName for backward compatibility).
  /// Does NOT borrow name from Destination catalog.
  String? get effectiveLocationName =>
      locationName ?? customLocationName;

  /// Authoritative display address: strictly from activity snapshot
  /// (locationAddress takes precedence, falling back to legacy customAddress for backward compatibility).
  /// Does NOT borrow address from Destination catalog.
  String? get effectiveAddress =>
      locationAddress ?? customAddress;

  /// Effective image URL: activity snapshot image, fallback to place image, fallback to legacy destination image.
  String? get effectiveImageUrl =>
      (imageUrl != null && imageUrl!.trim().isNotEmpty)
          ? imageUrl!.trim()
          : (place?.imageUrl != null && place!.imageUrl!.trim().isNotEmpty)
              ? place!.imageUrl!.trim()
              : destination?.imageUrl?.trim();

  /// Effective description: activity description, fallback to place description, fallback to legacy destination description.
  String? get effectiveDescription =>
      (description != null && description!.trim().isNotEmpty)
          ? description!.trim()
          : (place?.description != null && place!.description!.trim().isNotEmpty)
              ? place!.description!.trim()
              : destination?.description?.trim();
}
