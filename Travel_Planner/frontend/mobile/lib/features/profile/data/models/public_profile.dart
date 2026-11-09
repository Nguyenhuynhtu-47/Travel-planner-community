class PublicProfile {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatar;
  final String? bio;
  final DateTime? createdAt;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final bool isOwnProfile;

  const PublicProfile({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatar,
    this.bio,
    this.createdAt,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isOwnProfile = false,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    username: json['username']?.toString() ?? '',
    fullName: json['fullName']?.toString(),
    avatar: json['avatar']?.toString(),
    bio: json['bio']?.toString(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
    followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
    isFollowing: json['isFollowing'] == true,
    isOwnProfile: json['isOwnProfile'] == true,
  );

  PublicProfile copyWith({int? followerCount, bool? isFollowing}) =>
      PublicProfile(
        userId: userId,
        username: username,
        fullName: fullName,
        avatar: avatar,
        bio: bio,
        createdAt: createdAt,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        isFollowing: isFollowing ?? this.isFollowing,
        isOwnProfile: isOwnProfile,
      );
}
