class PublicUserSummary {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatar;

  const PublicUserSummary({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatar,
  });

  factory PublicUserSummary.fromJson(Map<String, dynamic> json) =>
      PublicUserSummary(
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        username: json['username']?.toString() ?? '',
        fullName: json['fullName']?.toString(),
        avatar: json['avatar']?.toString(),
      );
}
