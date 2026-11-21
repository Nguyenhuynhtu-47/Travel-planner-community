import '../messaging_date_time.dart';
import 'share_metadata.dart';

class ChatMessage {
  final int? messageId;
  final int conversationId;
  final int sequenceNumber;
  final int senderUserId;
  final String senderName;
  final String? senderHandle;
  final String? senderAvatar;
  final String clientMessageId;
  final String content;
  final DateTime createdAt;
  final bool sending;
  final bool failed;
  final String? conversationStatus;
  final bool recipientVisible;
  final String messageType;
  final String? shareTargetType;
  final int? shareTargetId;
  final ShareMetadata? shareMetadata;

  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.sequenceNumber,
    required this.senderUserId,
    required this.senderName,
    this.senderHandle,
    this.senderAvatar,
    required this.clientMessageId,
    required this.content,
    required this.createdAt,
    this.sending = false,
    this.failed = false,
    this.conversationStatus,
    this.recipientVisible = true,
    this.messageType = 'TEXT',
    this.shareTargetType,
    this.shareTargetId,
    this.shareMetadata,
  });

  bool get isShare => messageType.toUpperCase() == 'SHARE';
  bool get isText => !isShare;
  bool get isItineraryShare =>
      isShare && shareTargetType?.toUpperCase() == 'ITINERARY';
  bool get isPostShare => isShare && shareTargetType?.toUpperCase() == 'POST';

  /// Human-friendly display content for preview and fallback rendering.
  String get displayContent {
    if (content.trim().isNotEmpty) return content;
    if (isShare) {
      final title = shareMetadata?.title;
      if (title != null && title.trim().isNotEmpty) {
        return '[Chia sẻ] $title';
      }
      return isItineraryShare ? '[Chia sẻ lịch trình]' : '[Chia sẻ bài viết]';
    }
    return '';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    messageId: (json['messageId'] as num?)?.toInt(),
    conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
    sequenceNumber: (json['sequenceNumber'] as num?)?.toInt() ?? 0,
    senderUserId: (json['senderUserId'] as num?)?.toInt() ?? 0,
    senderName:
        json['senderName']?.toString() ??
        json['senderHandle']?.toString() ??
        '',
    senderHandle: json['senderHandle']?.toString(),
    senderAvatar: json['senderAvatar']?.toString(),
    clientMessageId: json['clientMessageId']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    createdAt:
        MessagingDateTime.parseApi(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    conversationStatus: json['conversationStatus']?.toString().toUpperCase(),
    recipientVisible: json['recipientVisible'] != false,
    messageType: json['messageType']?.toString().toUpperCase() ?? 'TEXT',
    shareTargetType: json['shareTargetType']?.toString().toUpperCase(),
    shareTargetId: (json['shareTargetId'] as num?)?.toInt(),
    shareMetadata: ShareMetadata.tryParse(json['shareMetadata']),
  );

  ChatMessage copyWith({
    int? messageId,
    int? sequenceNumber,
    bool? sending,
    bool? failed,
    String? conversationStatus,
    bool? recipientVisible,
    String? messageType,
    String? shareTargetType,
    int? shareTargetId,
    ShareMetadata? shareMetadata,
  }) => ChatMessage(
    messageId: messageId ?? this.messageId,
    conversationId: conversationId,
    sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    senderUserId: senderUserId,
    senderName: senderName,
    senderHandle: senderHandle,
    senderAvatar: senderAvatar,
    clientMessageId: clientMessageId,
    content: content,
    createdAt: createdAt,
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
    conversationStatus: conversationStatus ?? this.conversationStatus,
    recipientVisible: recipientVisible ?? this.recipientVisible,
    messageType: messageType ?? this.messageType,
    shareTargetType: shareTargetType ?? this.shareTargetType,
    shareTargetId: shareTargetId ?? this.shareTargetId,
    shareMetadata: shareMetadata ?? this.shareMetadata,
  );
}
