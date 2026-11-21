import 'dart:convert';

class ShareMetadata {
  final String? title;
  final String? coverImage;
  final String? subtitle;
  final String? authorName;
  final String? authorAvatar;
  final String? visibility;
  final String? status;

  const ShareMetadata({
    this.title,
    this.coverImage,
    this.subtitle,
    this.authorName,
    this.authorAvatar,
    this.visibility,
    this.status,
  });

  factory ShareMetadata.fromJson(Map<String, dynamic> json) => ShareMetadata(
    title: json['title']?.toString(),
    coverImage: json['coverImage']?.toString(),
    subtitle: json['subtitle']?.toString(),
    authorName: json['authorName']?.toString(),
    authorAvatar: json['authorAvatar']?.toString(),
    visibility: json['visibility']?.toString().toUpperCase(),
    status: json['status']?.toString().toUpperCase(),
  );

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (coverImage != null) 'coverImage': coverImage,
    if (subtitle != null) 'subtitle': subtitle,
    if (authorName != null) 'authorName': authorName,
    if (authorAvatar != null) 'authorAvatar': authorAvatar,
    if (visibility != null) 'visibility': visibility,
    if (status != null) 'status': status,
  };

  /// Safely attempts to parse [raw] metadata.
  /// [raw] can be a Map, or a JSON String (which is how Backend sends it in `share_metadata`),
  /// or null. Returns null if parsing fails or input is null without throwing.
  static ShareMetadata? tryParse(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return ShareMetadata.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return ShareMetadata.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
