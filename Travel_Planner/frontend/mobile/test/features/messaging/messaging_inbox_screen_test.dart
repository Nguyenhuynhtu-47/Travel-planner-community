import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/messaging/data/messaging_repository.dart';
import 'package:mobile/features/messaging/data/models/conversation_summary.dart';
import 'package:mobile/features/messaging/presentation/screens/messaging_inbox_screen.dart';
import 'package:mobile/features/messaging/presentation/screens/stranger_inbox_screen.dart';
import 'package:mobile/features/profile/data/models/public_user_summary.dart';

class _InboxAuth extends AuthNotifier {
  @override
  String? get token => 'token';

  @override
  Map<String, dynamic>? get currentUser => {'userId': 1};
}

class _InboxRepository extends MessagingRepository {
  int blockCalls = 0;
  int pendingCountCalls = 0;
  int conversationListCalls = 0;

  @override
  Future<PageResult<ConversationSummary>> conversations(
    String token, {
    int page = 0,
  }) async {
    conversationListCalls++;
    return PageResult(
      content: const [
        ConversationSummary(
          conversationId: 42,
          peer: PublicUserSummary(userId: 2, handle: 'traveler'),
          lastMessageSequence: 1,
          unreadCount: 0,
          canSendMessage: true,
        ),
      ],
      pageNumber: page,
      pageSize: 30,
      totalElements: 1,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<int> unreadMessageRequestCount(String token) async => 0;

  @override
  Future<PageResult<ConversationSummary>> messageRequests(
    String token, {
    int page = 0,
  }) async => PageResult(
    content: const [
      ConversationSummary(
        conversationId: 42,
        peer: PublicUserSummary(userId: 2, handle: 'traveler'),
        lastMessageSequence: 1,
        unreadCount: 0,
        canSendMessage: false,
        status: 'PENDING',
      ),
    ],
    pageNumber: page,
    pageSize: 30,
    totalElements: 1,
    totalPages: 1,
    isLast: true,
  );

  @override
  Future<int> pendingMessageRequestCount(String token) async {
    pendingCountCalls++;
    return 1;
  }

  @override
  @override
  Future<void> block(int userId, String token) async {
    expect(userId, 2);
    blockCalls++;
  }
}

void main() {
  testWidgets('Inbox menu keeps profile and block, with row click separate', (
    tester,
  ) async {
    final repository = _InboxRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MessagingInboxScreen(
          authNotifier: _InboxAuth(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@traveler'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Xem trang cá nhân'), findsOneWidget);
    expect(find.text('Chặn người dùng'), findsOneWidget);
    expect(find.text('Xóa cuộc trò chuyện'), findsNothing);
    await tester.tap(find.text('Chặn người dùng'));
    await tester.pumpAndSettle();

    expect(repository.blockCalls, 0);
    await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
    await tester.pumpAndSettle();
    expect(repository.blockCalls, 0);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chặn người dùng'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Chặn'));
    await tester.pumpAndSettle();

    expect(repository.blockCalls, 1);
    expect(repository.conversationListCalls, greaterThan(1));
    expect(repository.pendingCountCalls, 0);
  });

  testWidgets(
    'Stranger Inbox menu keeps row actions separate and confirms block',
    (tester) async {
      final repository = _InboxRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: StrangerInboxScreen(
            authNotifier: _InboxAuth(),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.text('Xem trang cá nhân'), findsOneWidget);
      expect(find.text('Chặn người dùng'), findsOneWidget);
      expect(find.text('Xóa cuộc trò chuyện'), findsNothing);
      await tester.tap(find.text('Chặn người dùng'));
      await tester.pumpAndSettle();

      expect(repository.blockCalls, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(repository.blockCalls, 0);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chặn người dùng'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Chặn'));
      await tester.pumpAndSettle();
      expect(repository.blockCalls, 1);
    },
  );
}
