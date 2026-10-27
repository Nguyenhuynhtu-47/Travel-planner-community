import 'activity_detail.dart';

class ItineraryDayDetail {
  final int dayId;
  final int dayNumber;
  final String? title;
  final String? description;
  final DateTime? date;
  final List<ActivityDetail> activities;

  const ItineraryDayDetail({
    required this.dayId,
    required this.dayNumber,
    this.title,
    this.description,
    this.date,
    required this.activities,
  });

  factory ItineraryDayDetail.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final activitiesList = <ActivityDetail>[];
    if (rawActivities is List) {
      for (final item in rawActivities) {
        if (item is Map) {
          activitiesList.add(
            ActivityDetail.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ItineraryDayDetail(
      dayId: json['dayId'] is num
          ? (json['dayId'] as num).toInt()
          : (int.tryParse(json['dayId']?.toString() ?? '') ?? 0),
      dayNumber: json['dayNumber'] is num
          ? (json['dayNumber'] as num).toInt()
          : (int.tryParse(json['dayNumber']?.toString() ?? '') ?? 1),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      date: json['date'] == null
          ? null
          : DateTime.tryParse(json['date'].toString()),
      activities: activitiesList,
    );
  }

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      if (trimmed.toLowerCase() == 'ngày $dayNumber'.toLowerCase()) {
        return trimmed;
      }
      if (trimmed.toLowerCase().startsWith('ngày $dayNumber:')) {
        return trimmed;
      }
      return 'Ngày $dayNumber: $trimmed';
    }
    return 'Ngày $dayNumber';
  }
}
