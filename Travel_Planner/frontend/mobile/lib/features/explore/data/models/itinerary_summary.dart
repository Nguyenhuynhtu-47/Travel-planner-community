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

    return ItinerarySummary(
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
      visibility: json['visibility']?.toString(),
      status: json['status']?.toString(),
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
      createdAt: parsedDate,
      creator: json['creator'] is Map<String, dynamic>
          ? CreatorSummary.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
    );
  }
}
