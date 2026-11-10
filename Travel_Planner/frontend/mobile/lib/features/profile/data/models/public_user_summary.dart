class PublicUserSummary {
  final int userId;
  final String handle;
  final String username;
  final String? fullName;
  final String? avatar;

  const PublicUserSummary({
    required this.userId,
    this.handle = '',
    this.username = '',
    this.fullName,
    this.avatar,
  });

  String get effectiveHandle => handle.isNotEmpty ? handle : username;

  factory PublicUserSummary.fromJson(Map<String, dynamic> json) =>
      PublicUserSummary(
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        handle: json['handle']?.toString() ?? json['username']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        fullName: json['fullName']?.toString(),
        avatar: json['avatar']?.toString(),
      );
}
