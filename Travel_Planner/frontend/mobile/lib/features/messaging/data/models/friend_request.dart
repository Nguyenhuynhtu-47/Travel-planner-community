import '../../../profile/data/models/public_user_summary.dart';

class FriendRequest {
  final int friendshipId;
  final String status;
  final String direction;
  final PublicUserSummary otherUser;
  final DateTime? createdAt;

  const FriendRequest({
    required this.friendshipId,
    required this.status,
    required this.direction,
    required this.otherUser,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    friendshipId: (json['friendshipId'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'PENDING',
    direction: json['direction']?.toString() ?? '',
    otherUser: PublicUserSummary.fromJson(
      Map<String, dynamic>.from(json['otherUser'] as Map? ?? const {}),
    ),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')
        ?.toLocal(),
  );
}
