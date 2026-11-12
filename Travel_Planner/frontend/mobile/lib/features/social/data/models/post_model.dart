class PostAuthorModel {
  final int userId;
  final String handle;
  final String? username;
  final String? fullName;
  final String? avatar;

  const PostAuthorModel({
    required this.userId,
    required this.handle,
    this.username,
    this.fullName,
    this.avatar,
  });

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!.trim()
      : (handle.startsWith('@') ? handle : '@$handle');

  factory PostAuthorModel.fromJson(Map<String, dynamic> json) {
    return PostAuthorModel(
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

class PostItineraryModel {
  final int itineraryId;
  final String title;
  final String? coverImage;
  final int? totalDays;
  final double? budget;
  final String? location;
  final double? averageRating;
  final PostAuthorModel? owner;

  const PostItineraryModel({
    required this.itineraryId,
    required this.title,
    this.coverImage,
    this.totalDays,
    this.budget,
    this.location,
    this.averageRating,
    this.owner,
  });

  factory PostItineraryModel.fromJson(Map<String, dynamic> json) {
    return PostItineraryModel(
      itineraryId: json['itineraryId'] is int
          ? json['itineraryId'] as int
          : int.tryParse('${json['itineraryId']}') ?? 0,
      title: json['title']?.toString() ?? '',
      coverImage: json['coverImage']?.toString(),
      totalDays: json['totalDays'] is int
          ? json['totalDays'] as int
          : int.tryParse('${json['totalDays']}'),
      budget: json['budget'] != null ? double.tryParse('${json['budget']}') : null,
      location: json['location']?.toString(),
      averageRating: json['averageRating'] != null
          ? double.tryParse('${json['averageRating']}')
          : null,
      owner: json['owner'] != null
          ? PostAuthorModel.fromJson(Map<String, dynamic>.from(json['owner'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'itineraryId': itineraryId,
    'title': title,
    'coverImage': coverImage,
    'totalDays': totalDays,
    'budget': budget,
    'location': location,
    'averageRating': averageRating,
    'owner': owner?.toJson(),
  };
}

class PostModel {
  final int postId;
  final String content;
  final PostAuthorModel author;
  final List<String> mediaUrls;
  final List<int> mediaAssetIds;
  final PostItineraryModel? itinerary;
  final bool itineraryUnavailable;
  final String? itineraryUnavailableReason;
  final String visibility;
  final String status;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final bool isOwner;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PostModel({
    required this.postId,
    required this.content,
    required this.author,
    required this.mediaUrls,
    required this.mediaAssetIds,
    this.itinerary,
    this.itineraryUnavailable = false,
    this.itineraryUnavailableReason,
    this.visibility = 'PUBLIC',
    this.status = 'ACTIVE',
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
    this.isOwner = false,
    required this.createdAt,
    this.updatedAt,
  });

  PostModel copyWith({
    int? postId,
    String? content,
    PostAuthorModel? author,
    List<String>? mediaUrls,
    List<int>? mediaAssetIds,
    PostItineraryModel? itinerary,
    bool? itineraryUnavailable,
    String? itineraryUnavailableReason,
    String? visibility,
    String? status,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
    bool? isOwner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      content: content ?? this.content,
      author: author ?? this.author,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaAssetIds: mediaAssetIds ?? this.mediaAssetIds,
      itinerary: itinerary ?? this.itinerary,
      itineraryUnavailable: itineraryUnavailable ?? this.itineraryUnavailable,
      itineraryUnavailableReason:
          itineraryUnavailableReason ?? this.itineraryUnavailableReason,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isOwner: isOwner ?? this.isOwner,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      postId: json['postId'] is int
          ? json['postId'] as int
          : int.tryParse('${json['postId']}') ?? 0,
      content: json['content']?.toString() ?? '',
      author: PostAuthorModel.fromJson(
          Map<String, dynamic>.from(json['author'] as Map? ?? {})),
      mediaUrls: (json['mediaUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mediaAssetIds: (json['mediaAssetIds'] as List<dynamic>?)
              ?.map((e) => e is int ? e : int.tryParse('$e') ?? 0)
              .toList() ??
          [],
      itinerary: json['itinerary'] != null
          ? PostItineraryModel.fromJson(
              Map<String, dynamic>.from(json['itinerary'] as Map))
          : null,
      itineraryUnavailable: json['itineraryUnavailable'] == true,
      itineraryUnavailableReason: json['itineraryUnavailableReason']?.toString(),
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      status: json['status']?.toString() ?? 'ACTIVE',
      likeCount: json['likeCount'] is int
          ? json['likeCount'] as int
          : int.tryParse('${json['likeCount']}') ?? 0,
      commentCount: json['commentCount'] is int
          ? json['commentCount'] as int
          : int.tryParse('${json['commentCount']}') ?? 0,
      isLikedByMe: json['isLikedByMe'] == true || json['likedByMe'] == true,
      isOwner: json['isOwner'] == true || json['owner'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'postId': postId,
    'content': content,
    'author': author.toJson(),
    'mediaUrls': mediaUrls,
    'mediaAssetIds': mediaAssetIds,
    'itinerary': itinerary?.toJson(),
    'itineraryUnavailable': itineraryUnavailable,
    'itineraryUnavailableReason': itineraryUnavailableReason,
    'visibility': visibility,
    'status': status,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'isLikedByMe': isLikedByMe,
    'isOwner': isOwner,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

