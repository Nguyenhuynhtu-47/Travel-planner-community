import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/messaging/data/messaging_repository.dart';
import 'package:mobile/features/messaging/data/models/share_batch_models.dart';
import 'package:mobile/features/messaging/presentation/widgets/share_bottom_sheet.dart';
import 'package:mobile/features/profile/data/models/public_user_summary.dart';

class MockMessagingRepository extends MessagingRepository {
  final List<PublicUserSummary> mockFriends;
  ShareBatchRequest? lastShareRequest;
  ShareBatchResponse? responseToReturn;

  MockMessagingRepository({required this.mockFriends});

  @override
  Future<PageResult<PublicUserSummary>> friends(String token, {int page = 0, int size = 50}) async {
    return PageResult<PublicUserSummary>(
      content: mockFriends,
      totalElements: mockFriends.length,
      totalPages: 1,
      pageSize: size,
      pageNumber: page,
      isLast: true,
    );
  }

  @override
  Future<ShareBatchResponse> shareContent(ShareBatchRequest request, String token) async {
    lastShareRequest = request;
    return responseToReturn ??
        ShareBatchResponse(
          targetType: request.targetType,
          targetId: request.targetId,
          totalRequested: request.recipientUserIds.length,
          successCount: request.recipientUserIds.length,
          failedCount: 0,
          results: request.recipientUserIds
              .map((id) => ShareBatchItemResponse(
                    recipientUserId: id,
                    success: true,
                  ))
              .toList(),
        );
  }
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  bool get isAuthenticated => true;

  @override
  String? get token => 'mock-token';

  @override
  Map<String, dynamic>? get currentUser => {
        'userId': 999,
        'email': 'tester@example.com',
      };
}

void main() {
  final mockFriendsList = [
    const PublicUserSummary(
      userId: 1,
      handle: 'alice',
      username: 'alice',
      fullName: 'Alice Nguyen',
      avatar: null,
    ),
    const PublicUserSummary(
      userId: 2,
      handle: 'bob',
      username: 'bob',
      fullName: 'Bob Tran',
      avatar: null,
    ),
  ];

  Widget buildTestSheet({
    required MockMessagingRepository repo,
    required AuthNotifier authNotifier,
    String targetType = 'POST',
    int targetId = 42,
    String title = 'Bài viết chia sẻ mẫu',
    String? subtitle = 'Mô tả bài viết',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ShareBottomSheet(
          targetType: targetType,
          targetId: targetId,
          title: title,
          subtitle: subtitle,
          authNotifier: authNotifier,
          messagingRepository: repo,
        ),
      ),
    );
  }

  group('ShareBottomSheet In-App Messaging UI Tests', () {
    testWidgets('Renders all required in-app messaging sharing elements and NO OS share shortcuts',
        (tester) async {
      final repo = MockMessagingRepository(mockFriends: mockFriendsList);
      final auth = FakeAuthNotifier();

      await tester.pumpWidget(buildTestSheet(repo: repo, authNotifier: auth));
      await tester.pumpAndSettle();

      // 1. Header and close button
      expect(find.text('Chia sẻ qua tin nhắn'), findsOneWidget);
      expect(find.text('Chọn bạn bè để gửi'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // 2. Preview card with badge and title
      expect(find.text('Bài viết'), findsOneWidget);
      expect(find.text('Bài viết chia sẻ mẫu'), findsOneWidget);
      expect(find.text('Mô tả bài viết'), findsOneWidget);

      // 3. Friends horizontal row
      expect(find.text('Alice Nguyen'), findsOneWidget);
      expect(find.text('Bob Tran'), findsOneWidget);

      // 5. Search field
      expect(find.widgetWithText(TextField, 'Tìm kiếm bạn bè...'), findsOneWidget);

      // 7. Message note input
      expect(find.widgetWithText(TextField, 'Soạn tin nhắn...'), findsOneWidget);

      // 8. Send button with initial label "Gửi"
      expect(find.text('Gửi'), findsOneWidget);

      // 4. CRITICAL: Verify NO OS/Android sharesheet shortcut elements exist
      expect(find.text('Chia sẻ lên tin'), findsNothing);
      expect(find.text('Bảng feed'), findsNothing);
      expect(find.text('Sao chép'), findsNothing);
      expect(find.text('Sao chép liên kết'), findsNothing);
      expect(find.text('Nhóm'), findsNothing);
      expect(find.text('Tìm bạn'), findsNothing);
    });

    testWidgets('Selects recipients, updates counter to Gửi (N), and shows selected chips',
        (tester) async {
      final repo = MockMessagingRepository(mockFriends: mockFriendsList);
      final auth = FakeAuthNotifier();

      await tester.pumpWidget(buildTestSheet(repo: repo, authNotifier: auth));
      await tester.pumpAndSettle();

      // Tap Alice to select
      await tester.tap(find.text('Alice Nguyen'));
      await tester.pumpAndSettle();

      // Verify header selection count and button label "Gửi (1)"
      expect(find.text('Đã chọn 1/10 người'), findsOneWidget);
      expect(find.text('Gửi (1)'), findsOneWidget);
      // Checkmark icon appears on selected avatar
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap Bob to select
      await tester.tap(find.text('Bob Tran'));
      await tester.pumpAndSettle();

      expect(find.text('Đã chọn 2/10 người'), findsOneWidget);
      expect(find.text('Gửi (2)'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2));

      // Enter optional message note
      await tester.enterText(find.widgetWithText(TextField, 'Soạn tin nhắn...'), 'Hãy cùng xem nhé!');
      await tester.pumpAndSettle();

      // Tap Send button
      await tester.tap(find.text('Gửi (2)'));
      await tester.pump();

      // Verify request payload sent to MessagingRepository
      expect(repo.lastShareRequest, isNotNull);
      expect(repo.lastShareRequest!.targetType, 'POST');
      expect(repo.lastShareRequest!.targetId, 42);
      expect(repo.lastShareRequest!.recipientUserIds, [1, 2]);
      expect(repo.lastShareRequest!.note, 'Hãy cùng xem nhé!');
    });

    testWidgets('Removes recipient via selected chip', (tester) async {
      final repo = MockMessagingRepository(mockFriends: mockFriendsList);
      final auth = FakeAuthNotifier();

      await tester.pumpWidget(buildTestSheet(repo: repo, authNotifier: auth));
      await tester.pumpAndSettle();

      // Select Alice
      await tester.tap(find.text('Alice Nguyen'));
      await tester.pumpAndSettle();
      expect(find.text('Gửi (1)'), findsOneWidget);

      // Tap close on the chip (icon Icons.close with size 14)
      final chipCloseFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.close && widget.size == 14,
      );
      expect(chipCloseFinder, findsOneWidget);
      await tester.tap(chipCloseFinder);
      await tester.pumpAndSettle();

      // Alice is deselected, button returns to "Gửi"
      expect(find.text('Chọn bạn bè để gửi'), findsOneWidget);
      expect(find.text('Gửi'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
