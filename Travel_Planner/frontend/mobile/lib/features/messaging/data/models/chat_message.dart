import '../messaging_date_time.dart';

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
  });

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
  );

  ChatMessage copyWith({
    int? messageId,
    int? sequenceNumber,
    bool? sending,
    bool? failed,
    String? conversationStatus,
    bool? recipientVisible,
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
  );
}
