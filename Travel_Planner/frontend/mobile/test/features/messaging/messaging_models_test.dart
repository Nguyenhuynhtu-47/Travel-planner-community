import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messaging/data/models/chat_event.dart';
import 'package:mobile/features/messaging/data/models/chat_message.dart';
import 'package:mobile/features/messaging/data/models/conversation_summary.dart';
import 'package:mobile/features/messaging/data/models/messaging_settings.dart';
import 'package:mobile/features/messaging/data/models/user_search_result.dart';
import 'package:mobile/features/messaging/data/messaging_realtime_client.dart';

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

  test('defaults absent inbound settings to everyone', () {
    expect(
      MessagingSettings.fromJson({}).inboundPolicy,
      InboundMessagePolicy.everyone,
    );
    expect(
      MessagingSettings.fromJson({'inboundPolicy': 'NOBODY'}).apiValue,
      'FRIENDS_ONLY',
    );
    expect(
      MessagingSettings.fromJson({'inboundPolicy': 'FRIENDS_ONLY'})
          .inboundPolicy,
      InboundMessagePolicy.friendsOnly,
    );
  });

  test('parses unread conversation summary and read event', () {
    final conversation = ConversationSummary.fromJson({
      'conversationId': 31,
      'peer': {'userId': 9, 'handle': 'travel9'},
      'lastMessageSequence': 12,
      'unreadCount': 3,
      'canSendMessage': true,
      'recipientPrivacyRestricted': true,
    });
    expect(conversation.unreadCount, 3);
    expect(conversation.recipientPrivacyRestricted, isTrue);
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

  test('parses pending message request actions and retry metadata', () {
    final availableAt = DateTime.utc(2026, 11, 18, 9);
    final conversation = ConversationSummary.fromJson({
      'conversationId': 77,
      'peer': {'userId': 12, 'handle': 'new-traveler'},
      'lastMessageSequence': 1,
      'unreadCount': 0,
      'canSendMessage': false,
      'status': 'PENDING',
      'canRespondToMessageRequest': true,
      'requestAvailableAt': availableAt.toIso8601String(),
    });

    expect(conversation.status, 'PENDING');
    expect(conversation.canRespondToMessageRequest, isTrue);
    expect(conversation.canSendMessage, isFalse);
    expect(conversation.requestAvailableAt, isNotNull);
  });

  test(
    'parses sender-only message visibility and current conversation state',
    () {
      final message = ChatMessage.fromJson({
        'conversationId': 23,
        'sequenceNumber': 5,
        'senderUserId': 1,
        'clientMessageId': 'sender-only',
        'content': 'Tin nhắn riêng phía người gửi',
        'createdAt': '2026-11-18T10:00:00',
        'conversationStatus': 'PENDING',
        'recipientVisible': false,
      });
      expect(message.conversationStatus, 'PENDING');
      expect(message.recipientVisible, isFalse);
    },
  );

  test(
    'parses public user search relationship states without login fields',
    () {
      final result = UserSearchResult.fromJson({
        'userId': 18,
        'handle': 'wanderer',
        'fullName': 'Wanderer',
        'avatar': 'https://example.test/avatar.png',
        'friendshipId': 71,
        'friendshipStatus': 'PENDING',
        'friendRequestDirection': 'received',
        'isSelf': false,
        'canMessage': false,
        'canSendFriendRequest': false,
      });
      expect(result.userId, 18);
      expect(result.handle, 'wanderer');
      expect(result.friendshipId, 71);
      expect(result.friendRequestDirection, 'received');
      expect(result.canSendFriendRequest, isFalse);
    },
  );

  test(
    'realtime client reports an invalid or expired token as failed',
    () async {
      final client = MessagingRealtimeClient();
      client.connect('not-a-jwt', 'user-1');

      expect(client.currentStatus, RealtimeStatus.failed);
      await client.dispose();
    },
  );
}
