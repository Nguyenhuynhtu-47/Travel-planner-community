import '../../../profile/data/models/public_user_summary.dart';
import '../messaging_date_time.dart';
import 'chat_message.dart';

class ConversationSummary {
  final int conversationId;
  final PublicUserSummary peer;
  final ChatMessage? lastMessage;
  final int lastMessageSequence;
  final int unreadCount;
  final bool canSendMessage;
  final String status;
  final bool canRespondToMessageRequest;
  final bool recipientPrivacyRestricted;
  final DateTime? requestAvailableAt;
  final DateTime? updatedAt;

  const ConversationSummary({
    required this.conversationId,
    required this.peer,
    this.lastMessage,
    required this.lastMessageSequence,
    required this.unreadCount,
    required this.canSendMessage,
    this.status = 'ACCEPTED',
    this.canRespondToMessageRequest = false,
    this.recipientPrivacyRestricted = false,
    this.requestAvailableAt,
    this.updatedAt,
  });

  factory ConversationSummary.fromJson(
    Map<String, dynamic> json,
  ) => ConversationSummary(
    conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
    peer: PublicUserSummary.fromJson(
      Map<String, dynamic>.from(json['peer'] as Map? ?? const {}),
    ),
    lastMessage: json['lastMessage'] is Map
        ? ChatMessage.fromJson(
            Map<String, dynamic>.from(json['lastMessage'] as Map),
          )
        : null,
    lastMessageSequence: (json['lastMessageSequence'] as num?)?.toInt() ?? 0,
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    canSendMessage: json['canSendMessage'] == true,
    status: json['status']?.toString().toUpperCase() ?? 'ACCEPTED',
    canRespondToMessageRequest: json['canRespondToMessageRequest'] == true,
    recipientPrivacyRestricted: json['recipientPrivacyRestricted'] == true,
    requestAvailableAt: MessagingDateTime.parseApi(json['requestAvailableAt']),
    updatedAt: MessagingDateTime.parseApi(json['updatedAt']),
  );
}
