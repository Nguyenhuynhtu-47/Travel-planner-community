import '../../../profile/data/models/public_user_summary.dart';
import 'chat_message.dart';

class ConversationSummary {
  final int conversationId;
  final PublicUserSummary peer;
  final ChatMessage? lastMessage;
  final int lastMessageSequence;
  final int unreadCount;
  final bool canSendMessage;
  final DateTime? updatedAt;

  const ConversationSummary({
    required this.conversationId,
    required this.peer,
    this.lastMessage,
    required this.lastMessageSequence,
    required this.unreadCount,
    required this.canSendMessage,
    this.updatedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
        peer: PublicUserSummary.fromJson(
          Map<String, dynamic>.from(json['peer'] as Map? ?? const {}),
        ),
        lastMessage: json['lastMessage'] is Map
            ? ChatMessage.fromJson(
                Map<String, dynamic>.from(json['lastMessage'] as Map),
              )
            : null,
        lastMessageSequence:
            (json['lastMessageSequence'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        canSendMessage: json['canSendMessage'] == true,
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')
            ?.toLocal(),
      );
}
