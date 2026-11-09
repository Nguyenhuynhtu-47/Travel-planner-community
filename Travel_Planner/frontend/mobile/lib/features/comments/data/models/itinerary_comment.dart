class ItineraryComment {
  final int commentId;
  final String content;
  final int? userId;
  final String? username;
  final String? fullName;
  final String? avatar;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? parentCommentId;
  final int? rootCommentId;
  final int replyCount;
  final bool deleted;
  final int? replyToUserId;
  final String? replyToName;
  final String? targetType;
  final int? targetId;

  const ItineraryComment({
    required this.commentId,
    required this.content,
    this.userId,
    this.username,
    this.fullName,
    this.avatar,
    this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.rootCommentId,
    this.replyCount = 0,
    this.deleted = false,
    this.replyToUserId,
    this.replyToName,
    this.targetType,
    this.targetId,
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
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      parentCommentId: (json['parentCommentId'] as num?)?.toInt(),
      rootCommentId: (json['rootCommentId'] as num?)?.toInt(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      deleted: json['deleted'] == true,
      replyToUserId: (json['replyToCreator'] as Map?)?['userId'] is num
          ? ((json['replyToCreator'] as Map)['userId'] as num).toInt()
          : null,
      replyToName: (json['replyToCreator'] as Map?)?['fullName']?.toString() ??
          (json['replyToCreator'] as Map?)?['username']?.toString(),
      targetType: json['targetType']?.toString(),
      targetId: (json['targetId'] as num?)?.toInt(),
    );
  }
}
