class CreatorSummary {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatar;

  const CreatorSummary({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatar,
  });

  factory CreatorSummary.fromJson(Map<String, dynamic> json) {
    return CreatorSummary(
      userId: json['userId'] is num
          ? (json['userId'] as num).toInt()
          : (int.tryParse(json['userId']?.toString() ?? '') ?? 0),
      username: json['username']?.toString() ?? 'anonymous',
      fullName: json['fullName']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    return username;
  }
}
