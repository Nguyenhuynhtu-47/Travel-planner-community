class UpdateItineraryRequest {
  final String title;
  final String? description;
  final String location;
  final String? coverImage;
  final double budget;
  final String? theme;
  final String visibility; // 'PUBLIC' or 'PRIVATE'

  const UpdateItineraryRequest({
    required this.title,
    this.description,
    required this.location,
    this.coverImage,
    required this.budget,
    this.theme,
    this.visibility = 'PRIVATE',
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'description': (description != null && description!.trim().isNotEmpty)
          ? description!.trim()
          : null,
      'location': location.trim(),
      'coverImage': (coverImage != null && coverImage!.trim().isNotEmpty)
          ? coverImage!.trim()
          : null,
      'budget': budget,
      'theme': (theme != null && theme!.trim().isNotEmpty)
          ? theme!.trim()
          : null,
      'visibility': visibility,
    };
  }
}
