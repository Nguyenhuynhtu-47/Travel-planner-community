import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messaging/data/models/chat_event.dart';
import 'package:mobile/features/messaging/data/models/chat_message.dart';
import 'package:mobile/features/messaging/data/models/conversation_summary.dart';
import 'package:mobile/features/messaging/data/models/messaging_settings.dart';

void main() {
  test('parses a persisted message and client idempotency key', () {
    final message = ChatMessage.fromJson({
      'messageId': 10,
      'conversationId': 4,
      'sequenceNumber': 7,
      'senderUserId': 2,
      'senderName': 'Người gửi',
      'clientMessageId': 'a8e731db-5a09-4809-9210-34ef60a695ba',
      'content': 'Xin chào',
      'createdAt': '2026-11-10T10:30:00',
    });
    expect(message.messageId, 10);
    expect(message.sequenceNumber, 7);
    expect(message.clientMessageId, startsWith('a8e731db'));
    expect(message.content, 'Xin chào');
  });

  test('defaults absent inbound settings to friends only', () {
    expect(
      MessagingSettings.fromJson({}).inboundPolicy,
      InboundMessagePolicy.friendsOnly,
    );
    expect(
      MessagingSettings.fromJson({'inboundPolicy': 'NOBODY'}).apiValue,
      'NOBODY',
    );
  });

  test('parses unread conversation summary and read event', () {
    final conversation = ConversationSummary.fromJson({
      'conversationId': 31,
      'peer': {'userId': 9, 'handle': 'travel9'},
      'lastMessageSequence': 12,
      'unreadCount': 3,
      'canSendMessage': true,
    });
    expect(conversation.unreadCount, 3);
    expect(conversation.peer.effectiveHandle, 'travel9');
    final event = ChatEvent.fromJson({
      'eventId': 'event-1',
      'type': 'READ_CURSOR_UPDATED',
      'conversationId': 31,
      'sequenceNumber': 12,
      'readerUserId': 9,
    });
    expect(event.readerUserId, 9);
    expect(event.sequenceNumber, 12);
  });
}
