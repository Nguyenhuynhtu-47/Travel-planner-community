import 'chat_message.dart';

class ChatEvent {
  final String eventId;
  final String type;
  final int conversationId;
  final int? sequenceNumber;
  final ChatMessage? message;
  final int? readerUserId;

  const ChatEvent({
    required this.eventId,
    required this.type,
    required this.conversationId,
    this.sequenceNumber,
    this.message,
    this.readerUserId,
  });

  factory ChatEvent.fromJson(Map<String, dynamic> json) => ChatEvent(
    eventId: json['eventId']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    conversationId: (json['conversationId'] as num?)?.toInt() ?? 0,
    sequenceNumber: (json['sequenceNumber'] as num?)?.toInt(),
    message: json['message'] is Map
        ? ChatMessage.fromJson(
            Map<String, dynamic>.from(json['message'] as Map),
          )
        : null,
    readerUserId: (json['readerUserId'] as num?)?.toInt(),
  );
}
