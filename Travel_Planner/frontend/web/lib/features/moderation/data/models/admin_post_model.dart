class AdminPostAuthorModel {
  final int userId;
  final String handle;
  final String? username;
  final String? fullName;
  final String? avatar;

  const AdminPostAuthorModel({
    required this.userId,
    required this.handle,
    this.username,
    this.fullName,
    this.avatar,
  });

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!.trim()
      : (handle.startsWith('@') ? handle : '@$handle');

  factory AdminPostAuthorModel.fromJson(Map<String, dynamic> json) {
    return AdminPostAuthorModel(
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}') ?? 0,
      handle: json['handle']?.toString() ?? '',
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'handle': handle,
    'username': username,
    'fullName': fullName,
    'avatar': avatar,
  };
}

class AdminPostModel {
  final int postId;
  final String content;
  final AdminPostAuthorModel author;
  final List<String> mediaUrls;
  final List<int> mediaAssetIds;
  final String visibility;
  final String status; // ACTIVE, HIDDEN, DELETED
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? moderatedAt;
  final String? moderationReason;

  const AdminPostModel({
    required this.postId,
    required this.content,
    required this.author,
    this.mediaUrls = const [],
    this.mediaAssetIds = const [],
    this.visibility = 'PUBLIC',
    this.status = 'ACTIVE',
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.moderatedAt,
    this.moderationReason,
  });

  factory AdminPostModel.fromJson(Map<String, dynamic> json) {
    final urls = <String>[];
    final assetIds = <int>[];

    // Primary: backend standard response DTO (mediaUrls & mediaAssetIds)
    if (json['mediaUrls'] is List) {
      urls.addAll((json['mediaUrls'] as List).map((e) => e.toString()));
    }
    if (json['mediaAssetIds'] is List) {
      assetIds.addAll((json['mediaAssetIds'] as List)
          .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
          .where((id) => id > 0));
    }

    // Fallback: media array of objects
    if (urls.isEmpty && json['media'] is List) {
      for (final item in json['media'] as List) {
        if (item is Map) {
          if (item['secureUrl'] != null) urls.add(item['secureUrl'].toString());
          if (item['mediaAssetId'] != null) {
            final id = item['mediaAssetId'] is int
                ? item['mediaAssetId'] as int
                : int.tryParse(item['mediaAssetId'].toString()) ?? 0;
            if (id > 0) assetIds.add(id);
          }
        }
      }
    }

    return AdminPostModel(
      postId: json['postId'] is int
          ? json['postId'] as int
          : int.tryParse('${json['postId']}') ?? 0,
      content: json['content']?.toString() ?? '',
      author: AdminPostAuthorModel.fromJson(
        Map<String, dynamic>.from(json['author'] as Map? ?? {}),
      ),
      mediaUrls: urls,
      mediaAssetIds: assetIds,
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      status: json['status']?.toString() ?? 'ACTIVE',
      likeCount: json['likeCount'] is int
          ? json['likeCount'] as int
          : int.tryParse('${json['likeCount']}') ?? 0,
      commentCount: json['commentCount'] is int
          ? json['commentCount'] as int
          : int.tryParse('${json['commentCount']}') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      moderatedAt: json['moderatedAt'] != null
          ? DateTime.tryParse(json['moderatedAt'].toString())
          : null,
      moderationReason: json['moderationReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'postId': postId,
    'content': content,
    'author': author.toJson(),
    'mediaUrls': mediaUrls,
    'mediaAssetIds': mediaAssetIds,
    'visibility': visibility,
    'status': status,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'moderatedAt': moderatedAt?.toIso8601String(),
    'moderationReason': moderationReason,
  };
}

