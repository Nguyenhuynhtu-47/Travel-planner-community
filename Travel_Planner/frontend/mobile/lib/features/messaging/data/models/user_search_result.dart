class UserSearchResult {
  final int userId;
  final String handle;
  final String? fullName;
  final String? avatar;
  final String? friendshipStatus;
  final int? friendshipId;
  final String? friendRequestDirection;
  final bool isSelf;
  final bool canMessage;
  final bool canContinueConversation;
  final bool canSendFriendRequest;

  const UserSearchResult({
    required this.userId,
    required this.handle,
    this.fullName,
    this.avatar,
    this.friendshipStatus,
    this.friendshipId,
    this.friendRequestDirection,
    this.isSelf = false,
    this.canMessage = false,
    this.canContinueConversation = false,
    this.canSendFriendRequest = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        handle: json['handle']?.toString() ?? '',
        fullName: json['fullName']?.toString(),
        avatar: json['avatar']?.toString(),
        friendshipStatus: json['friendshipStatus']?.toString(),
        friendshipId: (json['friendshipId'] as num?)?.toInt(),
        friendRequestDirection: json['friendRequestDirection']?.toString(),
        isSelf: json['isSelf'] == true,
        canMessage: json['canMessage'] == true,
        canContinueConversation: json['canContinueConversation'] == true,
        canSendFriendRequest: json['canSendFriendRequest'] == true,
      );
}
