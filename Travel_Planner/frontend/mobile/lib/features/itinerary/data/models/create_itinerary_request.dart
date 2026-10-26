class CreateItineraryRequest {
  final String title;
  final String? description;
  final String location;
  final String? coverImage;
  final int totalDays;
  final double budget;
  final String? theme;
  final String visibility; // 'PUBLIC' or 'PRIVATE'

  const CreateItineraryRequest({
    required this.title,
    this.description,
    required this.location,
    this.coverImage,
    required this.totalDays,
    required this.budget,
    this.theme,
    this.visibility = 'PRIVATE',
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'location': location.trim(),
      if (coverImage != null && coverImage!.trim().isNotEmpty)
        'coverImage': coverImage!.trim(),
      'totalDays': totalDays,
      'budget': budget,
      if (theme != null && theme!.trim().isNotEmpty) 'theme': theme!.trim(),
      'visibility': visibility,
    };
  }
}
