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
}
