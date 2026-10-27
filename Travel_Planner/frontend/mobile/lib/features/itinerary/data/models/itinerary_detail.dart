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
        if (item is Map) {
          daysList.add(
            ItineraryDayDetail.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawCreator = json['creator'];
    CreatorSummary? parsedCreator;
    if (rawCreator is Map) {
      parsedCreator = CreatorSummary.fromJson(
        Map<String, dynamic>.from(rawCreator),
      );
    }

    return ItineraryDetail(
      itineraryId: json['itineraryId'] is num
          ? (json['itineraryId'] as num).toInt()
          : (int.tryParse(json['itineraryId']?.toString() ?? '') ?? 0),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      location: json['location']?.toString() ?? '',
      coverImage: json['coverImage']?.toString(),
      totalDays: json['totalDays'] is num
          ? (json['totalDays'] as num).toInt()
          : (int.tryParse(json['totalDays']?.toString() ?? '') ?? 1),
      budget: rawBudget is num
          ? rawBudget.toDouble()
          : (num.tryParse(rawBudget?.toString() ?? '')?.toDouble() ?? 0.0),
      theme: json['theme']?.toString(),
      viewCount: json['viewCount'] is num
          ? (json['viewCount'] as num).toInt()
          : (int.tryParse(json['viewCount']?.toString() ?? '') ?? 0),
      favoriteCount: json['favoriteCount'] is num
          ? (json['favoriteCount'] as num).toInt()
          : (int.tryParse(json['favoriteCount']?.toString() ?? '') ?? 0),
      ratingCount: json['ratingCount'] is num
          ? (json['ratingCount'] as num).toInt()
          : (int.tryParse(json['ratingCount']?.toString() ?? '') ?? 0),
      averageRating: rawAverageRating is num
          ? rawAverageRating.toDouble()
          : (num.tryParse(rawAverageRating?.toString() ?? '')?.toDouble() ??
                0.0),
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      creator: parsedCreator,
      days: daysList,
    );
  }
}
