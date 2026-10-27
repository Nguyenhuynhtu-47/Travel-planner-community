import 'creator_summary.dart';

class ItinerarySummary {
  final int itineraryId;
  final String title;
  final String? description;
  final String location;
  final String? coverImage;
  final int totalDays;
  final double budget;
  final String? theme;
  final String? visibility;
  final String? status;
  final int viewCount;
  final int favoriteCount;
  final int ratingCount;
  final double averageRating;
  final DateTime? createdAt;
  final CreatorSummary? creator;

  const ItinerarySummary({
    required this.itineraryId,
    required this.title,
    this.description,
    required this.location,
    this.coverImage,
    required this.totalDays,
    required this.budget,
    this.theme,
    this.visibility,
    this.status,
    required this.viewCount,
    required this.favoriteCount,
    required this.ratingCount,
    required this.averageRating,
    this.createdAt,
    this.creator,
  });

  factory ItinerarySummary.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['createdAt'] != null) {
      parsedDate = DateTime.tryParse(json['createdAt'].toString());
    }

    final rawBudget = json['budget'];
    final rawAverageRating = json['averageRating'];

    final rawCreator = json['creator'];
    CreatorSummary? parsedCreator;
    if (rawCreator is Map) {
      parsedCreator = CreatorSummary.fromJson(
        Map<String, dynamic>.from(rawCreator),
      );
    }

    return ItinerarySummary(
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
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      status: json['status']?.toString() ?? 'ACTIVE',
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
      createdAt: parsedDate,
      creator: parsedCreator,
    );
  }
}
