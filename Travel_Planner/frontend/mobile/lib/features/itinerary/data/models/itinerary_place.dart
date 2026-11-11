import 'place_summary.dart';

class ItineraryPlace {
  final int id;
  final int itineraryId;
  final PlaceSummary place;
  final DateTime? savedAt;

  const ItineraryPlace({
    required this.id,
    required this.itineraryId,
    required this.place,
    this.savedAt,
  });

  factory ItineraryPlace.fromJson(Map<String, dynamic> json) {
    return ItineraryPlace(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      itineraryId: json['itineraryId'] is num
          ? (json['itineraryId'] as num).toInt()
          : (int.tryParse(json['itineraryId']?.toString() ?? '') ?? 0),
      place: PlaceSummary.fromJson(
        json['place'] is Map<String, dynamic>
            ? json['place'] as Map<String, dynamic>
            : (json['place'] is Map
                ? Map<String, dynamic>.from(json['place'] as Map)
                : {}),
      ),
      savedAt: json['savedAt'] != null
          ? DateTime.tryParse(json['savedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itineraryId': itineraryId,
      'place': place.toJson(),
      if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
    };
  }
}

