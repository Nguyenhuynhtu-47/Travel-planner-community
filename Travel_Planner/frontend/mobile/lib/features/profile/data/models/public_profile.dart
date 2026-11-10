class PublicProfile {
  final int userId;
  final String handle;
  final String username;
  final String? fullName;
  final String? avatar;
  final String? bio;
  final DateTime? createdAt;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final bool isOwnProfile;
  final String? friendshipStatus;
  final String? friendRequestDirection;
  final bool canMessage;
  final bool canSendFriendRequest;

  const PublicProfile({
    required this.userId,
    this.handle = '',
    this.username = '',
    this.fullName,
    this.avatar,
    this.bio,
    this.createdAt,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isOwnProfile = false,
    this.friendshipStatus,
    this.friendRequestDirection,
    this.canMessage = false,
    this.canSendFriendRequest = false,
  });

  String get effectiveHandle => handle.isNotEmpty ? handle : username;

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    handle: json['handle']?.toString() ?? json['username']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    fullName: json['fullName']?.toString(),
    avatar: json['avatar']?.toString(),
    bio: json['bio']?.toString(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
    followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
    isFollowing: json['isFollowing'] == true,
    isOwnProfile: json['isOwnProfile'] == true,
    friendshipStatus: json['friendshipStatus']?.toString(),
    friendRequestDirection: json['friendRequestDirection']?.toString(),
    canMessage: json['canMessage'] == true,
    canSendFriendRequest: json['canSendFriendRequest'] == true,
  );

  PublicProfile copyWith({
    int? followerCount,
    bool? isFollowing,
    String? handle,
  }) => PublicProfile(
    userId: userId,
    handle: handle ?? this.handle,
    username: username,
    fullName: fullName,
    avatar: avatar,
    bio: bio,
    createdAt: createdAt,
    followerCount: followerCount ?? this.followerCount,
    followingCount: followingCount,
    isFollowing: isFollowing ?? this.isFollowing,
    isOwnProfile: isOwnProfile,
    friendshipStatus: friendshipStatus,
    friendRequestDirection: friendRequestDirection,
    canMessage: canMessage,
    canSendFriendRequest: canSendFriendRequest,
  );
}
