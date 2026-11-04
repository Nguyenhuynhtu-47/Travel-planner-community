class SocialStateUpdate {
  final int itineraryId;
  final bool? isFavorited;
  final bool? isSaved;
  final int? userRating;
  final double? averageRating;
  final int? ratingCount;
  final int? favoriteCount;

  const SocialStateUpdate({
    required this.itineraryId,
    this.isFavorited,
    this.isSaved,
    this.userRating,
    this.averageRating,
    this.ratingCount,
    this.favoriteCount,
  });

  bool get hasChanges =>
      isFavorited != null ||
      isSaved != null ||
      userRating != null ||
      averageRating != null ||
      ratingCount != null ||
      favoriteCount != null;

  SocialStateUpdate copyWith({
    int? itineraryId,
    bool? isFavorited,
    bool? isSaved,
    int? userRating,
    double? averageRating,
    int? ratingCount,
    int? favoriteCount,
  }) {
    return SocialStateUpdate(
      itineraryId: itineraryId ?? this.itineraryId,
      isFavorited: isFavorited ?? this.isFavorited,
      isSaved: isSaved ?? this.isSaved,
      userRating: userRating ?? this.userRating,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
    );
  }
}

