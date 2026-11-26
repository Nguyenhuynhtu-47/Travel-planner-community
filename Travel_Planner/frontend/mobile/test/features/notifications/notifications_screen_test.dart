import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/notifications/data/models/notification_item.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets('shows sign-in guidance without requesting personal feed', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(repository: repository)),
    );

    expect(find.text('Đăng nhập để xem thông báo'), findsOneWidget);
    expect(repository.pageCalls, 0);
  });

  testWidgets('loads personal items and marks only the selected item read', (
    tester,
  ) async {
    final authNotifier = _FakeAuthNotifier();
    final repository = _FakeNotificationRepository(
      items: [
        NotificationItem(
          id: 8,
          type: 'FUTURE_SAFE_TYPE',
          title: 'Thông báo kiểm thử',
          body: 'Nội dung kiểm thử',
          actor: const NotificationActor(displayName: 'Người gửi'),
          createdAt: DateTime(2026, 11, 26),
          targetType: 'UNKNOWN',
          targetId: '5',
        ),
      ],
    );
    addTearDown(authNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          authNotifier: authNotifier,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông báo kiểm thử'), findsOneWidget);
    expect(find.text('Đọc tất cả'), findsOneWidget);
    await tester.tap(find.text('Thông báo kiểm thử'));
    await tester.pumpAndSettle();

    expect(repository.readIds, [8]);
    expect(
      find.text('Nội dung này chưa có liên kết mở trực tiếp.'),
      findsOneWidget,
    );
    expect(find.text('Đọc tất cả'), findsNothing);
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  bool get isAuthenticated => true;

  @override
  String? get token => 'test-token';

  @override
  Map<String, dynamic>? get currentUser => const {'userId': 12};
}

class _FakeNotificationRepository extends NotificationRepository {
  final List<NotificationItem> items;
  int pageCalls = 0;
  int unreadCount;
  final List<int> readIds = [];

  _FakeNotificationRepository({this.items = const []})
    : unreadCount = items.length;

  @override
  Future<NotificationPage> getPage(
    String token, {
    String? cursor,
    int size = 20,
  }) async {
    pageCalls++;
    return NotificationPage(items: items, nextCursor: null, hasMore: false);
  }

  @override
  Future<NotificationUnreadSummary> getUnreadSummary(String token) async =>
      NotificationUnreadSummary(
        count: unreadCount,
        personalCount: unreadCount,
        announcementCount: 0,
      );

  @override
  Future<void> markRead(int id, String token) async {
    readIds.add(id);
    unreadCount = (unreadCount - 1).clamp(0, 1 << 31);
  }
}
