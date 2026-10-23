import '../../../explore/data/models/creator_summary.dart';
import 'itinerary_day_detail.dart';

class ItineraryDetail {
  final int itineraryId;
  final String title;
  final String? description;
  final String location;
  final String? coverImage;
  final int totalDays;
  final double budget;
  final String? theme;
  final int viewCount;
  final int favoriteCount;
  final int ratingCount;
  final double averageRating;
  final String visibility;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CreatorSummary? creator;
  final List<ItineraryDayDetail> days;

  const ItineraryDetail({
    required this.itineraryId,
    required this.title,
    this.description,
    required this.location,
    this.coverImage,
    required this.totalDays,
    required this.budget,
    this.theme,
    required this.viewCount,
    required this.favoriteCount,
    required this.ratingCount,
    required this.averageRating,
    required this.visibility,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.creator,
    required this.days,
  });

  factory ItineraryDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'].toString());
    }

    DateTime? parsedUpdatedAt;
    if (json['updatedAt'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updatedAt'].toString());
    }

    final rawBudget = json['budget'];
    final rawAverageRating = json['averageRating'];

    final rawDays = json['days'];
    final daysList = <ItineraryDayDetail>[];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is Map<String, dynamic>) {
          daysList.add(ItineraryDayDetail.fromJson(item));
        }
      }
    }

    return ItineraryDetail(
      itineraryId: json['itineraryId'] is num
          ? (json['itineraryId'] as num).toInt()
          : 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      location: json['location']?.toString() ?? '',
      coverImage: json['coverImage']?.toString(),
      totalDays: json['totalDays'] is num
          ? (json['totalDays'] as num).toInt()
          : 1,
      budget: rawBudget is num ? rawBudget.toDouble() : 0.0,
      theme: json['theme']?.toString(),
      viewCount: json['viewCount'] is num
          ? (json['viewCount'] as num).toInt()
          : 0,
      favoriteCount: json['favoriteCount'] is num
          ? (json['favoriteCount'] as num).toInt()
          : 0,
      ratingCount: json['ratingCount'] is num
          ? (json['ratingCount'] as num).toInt()
          : 0,
      averageRating: rawAverageRating is num
          ? rawAverageRating.toDouble()
          : 0.0,
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      creator: json['creator'] is Map<String, dynamic>
          ? CreatorSummary.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
      days: daysList,
    );
  }
}
