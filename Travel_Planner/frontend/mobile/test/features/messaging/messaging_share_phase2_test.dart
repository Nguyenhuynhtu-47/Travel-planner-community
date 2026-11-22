import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/messaging/data/messaging_repository.dart';
import 'package:mobile/features/messaging/data/models/chat_event.dart';
import 'package:mobile/features/messaging/data/models/chat_message.dart';
import 'package:mobile/features/messaging/data/models/conversation_summary.dart';
import 'package:mobile/features/messaging/data/models/share_batch_models.dart';
import 'package:http/http.dart' as http;

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  group('Phase 2: In-App Content Sharing via Messaging Model & Integration Tests', () {

    // 1. Parse TEXT message cũ (không có các trường share)
    test('1. Parses legacy TEXT message without share fields', () {
      final json = {
        'messageId': 100,
        'conversationId': 10,
        'sequenceNumber': 1,
        'senderUserId': 2,
        'senderName': 'Alice',
        'clientMessageId': 'client-1',
        'content': 'Chào bạn!',
        'createdAt': '2026-11-21T10:00:00',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.messageId, 100);
      expect(message.messageType, 'TEXT');
      expect(message.isText, isTrue);
      expect(message.isShare, isFalse);
      expect(message.shareTargetType, isNull);
      expect(message.shareTargetId, isNull);
      expect(message.shareMetadata, isNull);
      expect(message.displayContent, 'Chào bạn!');
    });

    // 2. Parse SHARE itinerary
    test('2. Parses SHARE itinerary with JSON metadata string', () {
      final metadataJson = jsonEncode({
        'title': 'Chuyến đi Đà Lạt 3N2Đ',
        'coverImage': 'https://example.com/dalat.jpg',
        'subtitle': 'Đà Lạt - 3 ngày',
        'authorName': 'Bob',
        'authorAvatar': 'https://example.com/bob.jpg',
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
      });

      final json = {
        'messageId': 101,
        'conversationId': 10,
        'sequenceNumber': 2,
        'senderUserId': 1,
        'senderName': 'Bob',
        'clientMessageId': 'client-2',
        'content': 'Gợi ý lịch trình này nhé!',
        'createdAt': '2026-11-21T10:05:00',
        'messageType': 'SHARE',
        'shareTargetType': 'ITINERARY',
        'shareTargetId': 200,
        'shareMetadata': metadataJson,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.messageId, 101);
      expect(message.messageType, 'SHARE');
      expect(message.isShare, isTrue);
      expect(message.isText, isFalse);
      expect(message.isItineraryShare, isTrue);
      expect(message.isPostShare, isFalse);
      expect(message.shareTargetType, 'ITINERARY');
      expect(message.shareTargetId, 200);
      expect(message.shareMetadata, isNotNull);
      expect(message.shareMetadata!.title, 'Chuyến đi Đà Lạt 3N2Đ');
      expect(message.shareMetadata!.coverImage, 'https://example.com/dalat.jpg');
      expect(message.shareMetadata!.subtitle, 'Đà Lạt - 3 ngày');
      expect(message.shareMetadata!.authorName, 'Bob');
      expect(message.shareMetadata!.visibility, 'PUBLIC');
      expect(message.displayContent, 'Gợi ý lịch trình này nhé!');
    });

    // 3. Parse SHARE post
    test('3. Parses SHARE post with JSON metadata string and fallback display content', () {
      final metadataJson = jsonEncode({
        'title': 'Bài viết của Charlie',
        'coverImage': 'https://example.com/post.jpg',
        'subtitle': 'Hôm nay trời rất đẹp tại Sa Pa...',
        'authorName': 'Charlie',
        'authorAvatar': 'https://example.com/charlie.jpg',
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
      });

      final json = {
        'messageId': 102,
        'conversationId': 10,
        'sequenceNumber': 3,
        'senderUserId': 3,
        'senderName': 'Charlie',
        'clientMessageId': 'client-3',
        'content': '', // No optional note provided
        'createdAt': '2026-11-21T10:10:00',
        'messageType': 'SHARE',
        'shareTargetType': 'POST',
        'shareTargetId': 500,
        'shareMetadata': metadataJson,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.isShare, isTrue);
      expect(message.isPostShare, isTrue);
      expect(message.isItineraryShare, isFalse);
      expect(message.shareTargetType, 'POST');
      expect(message.shareTargetId, 500);
      expect(message.shareMetadata!.title, 'Bài viết của Charlie');
      expect(message.displayContent, '[Chia sẻ] Bài viết của Charlie');
    });

    // 4. Parse SHARE với metadata null hoặc chuỗi JSON hỏng
    test('4. Safely parses SHARE when metadata is null or malformed without crashing', () {
      final jsonNullMeta = {
        'messageId': 103,
        'conversationId': 10,
        'sequenceNumber': 4,
        'senderUserId': 1,
        'senderName': 'Bob',
        'clientMessageId': 'client-4',
        'content': 'Test',
        'createdAt': '2026-11-21T10:15:00',
        'messageType': 'SHARE',
        'shareTargetType': 'ITINERARY',
        'shareTargetId': 300,
        'shareMetadata': null,
      };

      final message1 = ChatMessage.fromJson(jsonNullMeta);
      expect(message1.isShare, isTrue);
      expect(message1.shareMetadata, isNull);

      final jsonMalformedMeta = {
        'messageId': 104,
        'conversationId': 10,
        'sequenceNumber': 5,
        'senderUserId': 1,
        'senderName': 'Bob',
        'clientMessageId': 'client-5',
        'content': '',
        'createdAt': '2026-11-21T10:20:00',
        'messageType': 'SHARE',
        'shareTargetType': 'ITINERARY',
        'shareTargetId': 300,
        'shareMetadata': '{not valid json',
      };

      final message2 = ChatMessage.fromJson(jsonMalformedMeta);
      expect(message2.isShare, isTrue);
      expect(message2.shareMetadata, isNull);
      expect(message2.displayContent, '[Chia sẻ lịch trình]');
    });

    // 5. Parse message thiếu messageType -> mặc định TEXT
    test('5. Message without messageType defaults to TEXT', () {
      final json = {
        'messageId': 105,
        'conversationId': 10,
        'sequenceNumber': 6,
        'senderUserId': 1,
        'senderName': 'Bob',
        'clientMessageId': 'client-6',
        'content': 'Default text',
        'createdAt': '2026-11-21T10:25:00',
      };

      final message = ChatMessage.fromJson(json);
      expect(message.messageType, 'TEXT');
      expect(message.isText, isTrue);
      expect(message.isShare, isFalse);
    });

    // 6. Parse batch response có nhiều recipient
    test('6. Parses ShareBatchResponse with multiple recipients', () {
      final responseJson = {
        'targetType': 'ITINERARY',
        'targetId': 100,
        'totalRequested': 2,
        'successCount': 2,
        'failedCount': 0,
        'results': [
          {
            'recipientUserId': 2,
            'recipientUsername': 'user2',
            'recipientFullName': 'User Two',
            'success': true,
            'errorMessage': null,
            'conversationId': 10,
            'messageId': 101,
            'sequenceNumber': 6,
          },
          {
            'recipientUserId': 3,
            'recipientUsername': 'user3',
            'recipientFullName': 'User Three',
            'success': true,
            'errorMessage': null,
            'conversationId': 12,
            'messageId': 102,
            'sequenceNumber': 1,
          },
        ],
      };

      final batch = ShareBatchResponse.fromJson(responseJson);

      expect(batch.targetType, 'ITINERARY');
      expect(batch.targetId, 100);
      expect(batch.totalRequested, 2);
      expect(batch.successCount, 2);
      expect(batch.failedCount, 0);
      expect(batch.isAllSuccess, isTrue);
      expect(batch.isPartialSuccess, isFalse);
      expect(batch.isAllFailed, isFalse);
      expect(batch.results.length, 2);
      expect(batch.results[0].recipientUserId, 2);
      expect(batch.results[0].success, isTrue);
      expect(batch.results[1].recipientUserId, 3);
      expect(batch.results[1].conversationId, 12);
    });

    // 7. Xử lý batch partial success (1 success, 1 failure)
    test('7. Parses ShareBatchResponse with partial success and error messages', () {
      final responseJson = {
        'targetType': 'POST',
        'targetId': 400,
        'totalRequested': 2,
        'successCount': 1,
        'failedCount': 1,
        'results': [
          {
            'recipientUserId': 2,
            'recipientUsername': 'user2',
            'recipientFullName': 'User Two',
            'success': true,
            'errorMessage': null,
            'conversationId': 10,
            'messageId': 103,
            'sequenceNumber': 7,
          },
          {
            'recipientUserId': 4,
            'recipientUsername': 'user4',
            'recipientFullName': 'User Four',
            'success': false,
            'errorMessage': 'Không thể gửi tin nhắn cho người dùng này',
            'conversationId': null,
            'messageId': null,
            'sequenceNumber': null,
          },
        ],
      };

      final batch = ShareBatchResponse.fromJson(responseJson);

      expect(batch.isAllSuccess, isFalse);
      expect(batch.isPartialSuccess, isTrue);
      expect(batch.isAllFailed, isFalse);
      expect(batch.successCount, 1);
      expect(batch.failedCount, 1);
      expect(batch.results[1].success, isFalse);
      expect(batch.results[1].errorMessage, 'Không thể gửi tin nhắn cho người dùng này');
      expect(batch.results[1].messageId, isNull);
    });

    // 8. Gửi SHARE request đúng JSON structure
    test('8. ShareBatchRequest serializes correctly to JSON', () {
      final requestWithNote = ShareBatchRequest(
        targetType: 'itinerary',
        targetId: 100,
        recipientUserIds: [2, 3],
        note: 'Hãy xem lịch trình này!',
      );

      final json1 = requestWithNote.toJson();
      expect(json1['targetType'], 'ITINERARY');
      expect(json1['targetId'], 100);
      expect(json1['recipientUserIds'], [2, 3]);
      expect(json1['note'], 'Hãy xem lịch trình này!');

      final requestWithoutNote = ShareBatchRequest(
        targetType: 'POST',
        targetId: 50,
        recipientUserIds: [5],
      );

      final json2 = requestWithoutNote.toJson();
      expect(json2['targetType'], 'POST');
      expect(json2['targetId'], 50);
      expect(json2['recipientUserIds'], [5]);
      expect(json2.containsKey('note'), isFalse);
    });

    // 9. Parse SHARE từ REST history (MessagePage)
    test('9. Parses mixed TEXT and SHARE messages from REST messages endpoint', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.path.contains('/api/conversations/10/messages')) {
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'messageId': 1,
                  'conversationId': 10,
                  'sequenceNumber': 1,
                  'senderUserId': 1,
                  'senderName': 'Bob',
                  'clientMessageId': 'c1',
                  'content': 'Xin chào',
                  'createdAt': '2026-11-21T10:00:00',
                  'messageType': 'TEXT',
                },
                {
                  'messageId': 2,
                  'conversationId': 10,
                  'sequenceNumber': 2,
                  'senderUserId': 2,
                  'senderName': 'Alice',
                  'clientMessageId': 'c2',
                  'content': 'Xem nè',
                  'createdAt': '2026-11-21T10:01:00',
                  'messageType': 'SHARE',
                  'shareTargetType': 'ITINERARY',
                  'shareTargetId': 99,
                  'shareMetadata': jsonEncode({'title': 'Tour Huế'}),
                },
              ],
              'hasMore': false,
              'nextBeforeSequence': null,
              'lastSequence': 2,
              'peerReadSequence': 2,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = MessagingRepository(apiClient: ApiClient(client: mockClient));
      final page = await repo.messages(10, 'mock-token');

      expect(page.content.length, 2);
      expect(page.content[0].isText, isTrue);
      expect(page.content[1].isShare, isTrue);
      expect(page.content[1].shareTargetId, 99);
      expect(page.content[1].shareMetadata!.title, 'Tour Huế');
    });

    // 10. Parse SHARE từ STOMP MESSAGE_CREATED
    test('10. Parses ChatEvent with type MESSAGE_CREATED containing SHARE message', () {
      final eventJson = {
        'eventId': 'event-uuid-1',
        'type': 'MESSAGE_CREATED',
        'conversationId': 10,
        'sequenceNumber': 8,
        'message': {
          'messageId': 205,
          'conversationId': 10,
          'sequenceNumber': 8,
          'senderUserId': 2,
          'senderName': 'Alice',
          'clientMessageId': 'c-realtime-1',
          'content': 'Lịch trình hay lắm',
          'createdAt': '2026-11-21T10:30:00',
          'messageType': 'SHARE',
          'shareTargetType': 'ITINERARY',
          'shareTargetId': 77,
          'shareMetadata': jsonEncode({
            'title': 'Khám phá Phú Quốc',
            'subtitle': 'Phú Quốc 4 ngày',
          }),
        },
      };

      final event = ChatEvent.fromJson(eventJson);

      expect(event.type, 'MESSAGE_CREATED');
      expect(event.conversationId, 10);
      expect(event.sequenceNumber, 8);
      expect(event.message, isNotNull);
      expect(event.message!.isShare, isTrue);
      expect(event.message!.shareTargetType, 'ITINERARY');
      expect(event.message!.shareTargetId, 77);
      expect(event.message!.shareMetadata!.title, 'Khám phá Phú Quốc');
    });

    // 11. REST và STOMP cùng trả một message không tạo duplicate (De-duplication test)
    test('11. De-duplication logic replaces message by messageId or clientMessageId', () {
      final List<ChatMessage> messages = [];

      void merge(List<ChatMessage> incoming) {
        for (final message in incoming) {
          final i = messages.indexWhere(
            (m) =>
                (message.messageId != null && m.messageId == message.messageId) ||
                m.clientMessageId == message.clientMessageId,
          );
          if (i >= 0) {
            messages[i] = message;
          } else {
            messages.add(message);
          }
        }
        messages.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      }

      final messageFromRest = ChatMessage.fromJson({
        'messageId': 101,
        'conversationId': 10,
        'sequenceNumber': 5,
        'senderUserId': 1,
        'senderName': 'Bob',
        'clientMessageId': 'shared-client-id',
        'content': 'From REST',
        'createdAt': '2026-11-21T10:00:00',
        'messageType': 'SHARE',
        'shareTargetType': 'ITINERARY',
        'shareTargetId': 10,
      });

      merge([messageFromRest]);
      expect(messages.length, 1);
      expect(messages.first.content, 'From REST');

      // STOMP arrives with same messageId and clientMessageId
      final messageFromStomp = ChatMessage.fromJson({
        'messageId': 101,
        'conversationId': 10,
        'sequenceNumber': 5,
        'senderUserId': 1,
        'senderName': 'Bob',
        'clientMessageId': 'shared-client-id',
        'content': 'From STOMP',
        'createdAt': '2026-11-21T10:00:00',
        'messageType': 'SHARE',
        'shareTargetType': 'ITINERARY',
        'shareTargetId': 10,
      });

      merge([messageFromStomp]);
      expect(messages.length, 1); // No duplicate added!
      expect(messages.first.content, 'From STOMP'); // Updated in place
    });

    // 12. Sequence number và thứ tự tin nhắn không thay đổi (sorted by sequenceNumber)
    test('12. Messages are strictly ordered by sequenceNumber', () {
      final List<ChatMessage> messages = [];

      void merge(List<ChatMessage> incoming) {
        for (final message in incoming) {
          final i = messages.indexWhere(
            (m) =>
                (message.messageId != null && m.messageId == message.messageId) ||
                m.clientMessageId == message.clientMessageId,
          );
          if (i >= 0) {
            messages[i] = message;
          } else {
            messages.add(message);
          }
        }
        messages.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      }

      final msgSeq3 = ChatMessage(
        messageId: 3,
        conversationId: 1,
        sequenceNumber: 3,
        senderUserId: 1,
        senderName: 'User',
        clientMessageId: 'c3',
        content: 'Seq 3',
        createdAt: DateTime.now(),
      );

      final msgSeq1 = ChatMessage(
        messageId: 1,
        conversationId: 1,
        sequenceNumber: 1,
        senderUserId: 1,
        senderName: 'User',
        clientMessageId: 'c1',
        content: 'Seq 1',
        createdAt: DateTime.now(),
      );

      final msgSeq2 = ChatMessage(
        messageId: 2,
        conversationId: 1,
        sequenceNumber: 2,
        senderUserId: 1,
        senderName: 'User',
        clientMessageId: 'c2',
        content: 'Seq 2',
        createdAt: DateTime.now(),
        messageType: 'SHARE',
        shareTargetType: 'ITINERARY',
        shareTargetId: 88,
      );

      merge([msgSeq3, msgSeq1, msgSeq2]);

      expect(messages.map((m) => m.sequenceNumber).toList(), [1, 2, 3]);
      expect(messages[1].isShare, isTrue);
    });

    // 13. Unread count không bị cập nhật hai lần (idempotency check)
    test('13. Read cursor idempotency: does not mark read if already read up to sequence', () {
      int peerReadSequence = 5;

      int updateReadCursor(int newSequence) {
        if (newSequence > peerReadSequence) {
          peerReadSequence = newSequence;
        }
        return peerReadSequence;
      }

      expect(updateReadCursor(5), 5); // duplicate event: no change
      expect(updateReadCursor(4), 5); // older event: ignored
      expect(updateReadCursor(6), 6); // newer event: updated
    });

    // 14. TEXT realtime vẫn hoạt động bình thường
    test('14. TEXT realtime MESSAGE_CREATED event parses and preserves behavior', () {
      final eventJson = {
        'eventId': 'event-text-1',
        'type': 'MESSAGE_CREATED',
        'conversationId': 20,
        'sequenceNumber': 3,
        'message': {
          'messageId': 55,
          'conversationId': 20,
          'sequenceNumber': 3,
          'senderUserId': 4,
          'senderName': 'David',
          'clientMessageId': 'c-text-1',
          'content': 'Hello there',
          'createdAt': '2026-11-21T10:40:00',
          'messageType': 'TEXT',
        },
      };

      final event = ChatEvent.fromJson(eventJson);
      expect(event.message!.isText, isTrue);
      expect(event.message!.isShare, isFalse);
      expect(event.message!.content, 'Hello there');
    });

    // 15. Xử lý lỗi API (ApiException) và WebSocket
    test('15. Repository shareContent maps API error responses correctly', () async {
      final mockClient = MockHttpClient((request) async {
        if (request.url.path == '/api/conversations/shares') {
          return http.Response(
            jsonEncode({
              'status': 400,
              'message': 'Chỉ được chia sẻ tối đa 10 người nhận mỗi lần',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = MessagingRepository(apiClient: ApiClient(client: mockClient));
      final req = ShareBatchRequest(
        targetType: 'ITINERARY',
        targetId: 1,
        recipientUserIds: List.generate(11, (i) => i + 1),
      );

      expect(
        () async => await repo.shareContent(req, 'mock-token'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Chỉ được chia sẻ tối đa 10 người nhận mỗi lần',
        )),
      );
    });

    // 16. Regression các luồng Messaging hiện tại (ConversationSummary with lastMessage SHARE)
    test('16. ConversationSummary parses lastMessage of type SHARE cleanly', () {
      final conversationJson = {
        'conversationId': 88,
        'peer': {
          'userId': 5,
          'handle': 'travel_buddy',
          'fullName': 'Travel Buddy',
        },
        'lastMessage': {
          'messageId': 999,
          'conversationId': 88,
          'sequenceNumber': 15,
          'senderUserId': 5,
          'senderName': 'Travel Buddy',
          'clientMessageId': 'c-last',
          'content': '',
          'createdAt': '2026-11-21T11:00:00',
          'messageType': 'SHARE',
          'shareTargetType': 'ITINERARY',
          'shareTargetId': 42,
          'shareMetadata': jsonEncode({'title': 'Du lịch Nha Trang'}),
        },
        'lastMessageSequence': 15,
        'unreadCount': 1,
        'canSendMessage': true,
        'status': 'ACCEPTED',
      };

      final summary = ConversationSummary.fromJson(conversationJson);

      expect(summary.conversationId, 88);
      expect(summary.lastMessage, isNotNull);
      expect(summary.lastMessage!.isShare, isTrue);
      expect(summary.lastMessage!.displayContent, '[Chia sẻ] Du lịch Nha Trang');
      expect(summary.unreadCount, 1);
    });

  });
}
