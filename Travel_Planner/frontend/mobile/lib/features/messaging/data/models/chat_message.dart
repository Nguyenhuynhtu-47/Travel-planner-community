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
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  ChatMessage copyWith({
    int? messageId,
    int? sequenceNumber,
    bool? sending,
    bool? failed,
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
  );
}
