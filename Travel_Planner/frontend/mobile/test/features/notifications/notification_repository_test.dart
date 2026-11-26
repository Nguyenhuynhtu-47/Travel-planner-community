import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/features/notifications/data/models/notification_item.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/core/network/api_client.dart';

void main() {
  group('NotificationItem', () {
    test('parses core fields and optional actor/read state', () {
      final item = NotificationItem.fromJson({
        'id': 42,
        'type': 'SYSTEM',
        'actionType': 'POST_HIDDEN',
        'title': 'Có bình luận mới',
        'body': 'Lan đã bình luận bài viết của bạn',
        'targetType': 'POST',
        'targetId': '9',
        'actor': {
          'userId': 7,
          'displayName': 'Lan',
          'handle': '@lan',
          'avatar': 'https://example.test/avatar.png',
        },
        'createdAt': '2026-11-26T10:30:00',
        'readAt': null,
      });

      expect(item.id, 42);
      expect(item.type, 'SYSTEM');
      expect(item.actionType, 'POST_HIDDEN');
      expect(item.actor.userId, 7);
      expect(item.actor.displayName, 'Lan');
      expect(item.isRead, isFalse);
    });

    test('keeps unknown notification types renderable', () {
      final item = NotificationItem.fromJson({
        'id': 1,
        'type': 'FUTURE_TYPE',
        'createdAt': '2026-11-26T10:30:00',
      });

      expect(item.type, 'FUTURE_TYPE');
      expect(item.title, isEmpty);
      expect(item.actor.userId, isNull);
    });

    test('identifies announcement source independently of its numeric id', () {
      final item = NotificationItem.fromJson({
        'id': 1,
        'type': 'SYSTEM',
        'targetType': 'ANNOUNCEMENT',
        'targetId': '1',
        'announcement': true,
        'createdAt': '2026-11-26T10:30:00',
      });
      expect(item.isAnnouncement, isTrue);
      expect(item.stableKey, 'announcement:1');
      expect(item.isRead, isFalse);
    });

    test('rejects an item without stable id or timestamp', () {
      expect(
        () => NotificationItem.fromJson({'type': 'POST_LIKE'}),
        throwsFormatException,
      );
    });
  });

  group('NotificationRepository', () {
    test('uses cursor feed and bounded size contract', () async {
      late http.Request request;
      final client = MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'content': [
              {
                'id': 5,
                'type': 'NEW_FOLLOWER',
                'createdAt': '2026-11-26T10:00:00',
              },
            ],
            'nextCursor': 'cursor-1',
            'hasMore': true,
          }),
          200,
        );
      });
      final repository = NotificationRepository(
        apiClient: ApiClient(client: client),
      );

      final page = await repository.getPage(
        'jwt-token',
        cursor: 'cursor-0',
        size: 25,
      );

      expect(request.method, 'GET');
      expect(request.url.path, '/api/notifications');
      expect(request.url.queryParameters['cursor'], 'cursor-0');
      expect(request.url.queryParameters['size'], '25');
      expect(request.headers['authorization'], 'Bearer jwt-token');
      expect(page.items.single.id, 5);
      expect(page.nextCursor, 'cursor-1');
      expect(page.hasMore, isTrue);
    });

    test(
      'reads authoritative unread count and sends owned read actions',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/unread-count')) {
            return http.Response('{"count":3}', 200);
          }
          return http.Response('', 204);
        });
        final repository = NotificationRepository(
          apiClient: ApiClient(client: client),
        );

        expect(await repository.getUnreadCount('jwt-token'), 3);
        await repository.markRead(12, 'jwt-token');
        await repository.markAnnouncementRead(12, 'jwt-token');
        await repository.markAllRead('jwt-token');

        expect(requests.map((request) => request.url.path), [
          '/api/notifications/unread-count',
          '/api/notifications/12/read',
          '/api/announcements/12/read',
          '/api/notifications/read-all',
        ]);
        expect(requests.last.method, 'POST');
        expect(requests.last.headers['authorization'], 'Bearer jwt-token');
      },
    );
  });
}
