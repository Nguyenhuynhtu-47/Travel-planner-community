class ItineraryComment {
  final int commentId;
  final String content;
  final int? userId;
  final String? username;
  final String? fullName;
  final String? avatar;
  final DateTime? createdAt;

  const ItineraryComment({
    required this.commentId,
    required this.content,
    this.userId,
    this.username,
    this.fullName,
    this.avatar,
    this.createdAt,
  });

  factory ItineraryComment.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] is Map
        ? Map<String, dynamic>.from(json['creator'] as Map)
        : <String, dynamic>{};
    final rawId = json['commentId'];
    return ItineraryComment(
      commentId: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      content: json['content']?.toString() ?? '',
      userId: creator['userId'] is num ? (creator['userId'] as num).toInt() : null,
      username: creator['username']?.toString(),
      fullName: creator['fullName']?.toString(),
      avatar: creator['avatar']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
