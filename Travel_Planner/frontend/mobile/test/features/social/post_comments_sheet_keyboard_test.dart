import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/social/data/community_post_repository.dart';
import 'package:mobile/features/social/data/models/post_comment_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/presentation/community_feed_notifier.dart';
import 'package:mobile/features/social/presentation/widgets/post_comments_sheet.dart';

class _MockPostRepo extends CommunityPostRepository {
  List<PostCommentModel> comments = [];
  int addCommentCount = 0;
  String? lastCommentText;

  @override
  Future<List<PostCommentModel>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    return List.from(comments);
  }

  @override
  Future<PostCommentModel> addComment(
    int postId, {
    required String content,
    int? parentCommentId,
    required String token,
  }) async {
    addCommentCount++;
    lastCommentText = content;
    final newComment = PostCommentModel(
      commentId: 9990 + addCommentCount,
      postId: postId,
      content: content,
      author: const PostAuthorModel(
        userId: 1,
        handle: 'test_user',
        fullName: 'Test User',
      ),
      isOwner: true,
      createdAt: DateTime.now(),
    );
    return newComment;
  }
}

void main() {
  late _MockPostRepo mockRepo;
  late CommunityFeedNotifier notifier;

  setUp(() {
    mockRepo = _MockPostRepo();
    notifier = CommunityFeedNotifier(repository: mockRepo);
  });

  tearDown(() {
    notifier.dispose();
  });

  Widget buildTestWidget({
    required Size screenSize,
    required double keyboardHeight,
    required Widget child,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: screenSize,
        viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        padding: const EdgeInsets.only(top: 24, bottom: 16),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets(
    'PostCommentsSheet: adjusts height, keeps input visible above keyboard, preserves text and submits accurately',
    (tester) async {
      mockRepo.comments = [
        PostCommentModel(
          commentId: 1,
          postId: 10,
          content: 'Bình luận số 1 rất dài để kiểm tra danh sách cuộn độc lập',
          author: const PostAuthorModel(
            userId: 2,
            handle: 'alice',
            fullName: 'Alice Walker',
          ),
          isOwner: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        PostCommentModel(
          commentId: 2,
          postId: 10,
          content: 'Bình luận số 2 chia sẻ kinh nghiệm du lịch thực tế',
          author: const PostAuthorModel(
            userId: 3,
            handle: 'bob',
            fullName: 'Bob Smith',
          ),
          isOwner: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      const screenSize = Size(360, 640);

      // 1. Render without keyboard (keyboardHeight = 0)
      await tester.pumpWidget(
        buildTestWidget(
          screenSize: screenSize,
          keyboardHeight: 0,
          child: PostCommentsSheet(
            postId: 10,
            token: 'valid_jwt_token',
            repository: mockRepo,
            notifier: notifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and existing comments
      expect(find.text('Bình luận'), findsOneWidget);
      expect(find.text('Bình luận số 1 rất dài để kiểm tra danh sách cuộn độc lập'), findsOneWidget);
      expect(find.text('Bình luận số 2 chia sẻ kinh nghiệm du lịch thực tế'), findsOneWidget);

      // Check text input field is visible at the bottom
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      final initialInputY = tester.getTopLeft(inputFinder).dy;

      // 2. Type text into the comment input field
      await tester.enterText(inputFinder, 'Nội dung bình luận đang soạn thảo');
      await tester.pumpAndSettle();
      expect(find.text('Nội dung bình luận đang soạn thảo'), findsOneWidget);

      // 3. Simulate on-screen keyboard appearing (viewInsets.bottom = 280)
      await tester.pumpWidget(
        buildTestWidget(
          screenSize: screenSize,
          keyboardHeight: 280,
          child: PostCommentsSheet(
            postId: 10,
            token: 'valid_jwt_token',
            repository: mockRepo,
            notifier: notifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check no layout overflow occurred
      expect(tester.takeException(), isNull);

      // Verify the input field was moved UP by the keyboard
      final keyboardInputY = tester.getTopLeft(inputFinder).dy;
      expect(
        keyboardInputY,
        lessThan(initialInputY),
        reason: 'Input field must be lifted above keyboard height',
      );
      // Input field bottom must be <= available height (640 - 280 = 360)
      final inputBottomY = tester.getBottomLeft(inputFinder).dy;
      expect(
        inputBottomY,
        lessThanOrEqualTo(640 - 280 + 10), // within safe padding
        reason: 'Input field must stay strictly above the keyboard',
      );

      // Content being typed is NOT lost
      expect(find.text('Nội dung bình luận đang soạn thảo'), findsOneWidget);

      // 4. Test independent scrolling of comments list while keyboard is up
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
      await tester.drag(listFinder, const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 5. Submit comment with send button
      final sendButton = find.byIcon(Icons.send_rounded);
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pump(); // Start request
      await tester.pump(const Duration(milliseconds: 200)); // Complete request
      await tester.pumpAndSettle();

      expect(mockRepo.addCommentCount, equals(1));
      expect(mockRepo.lastCommentText, equals('Nội dung bình luận đang soạn thảo'));

      // New comment appears in list and text field is cleared
      expect(find.text('Nội dung bình luận đang soạn thảo'), findsOneWidget); // now in comment card
      final textFieldWidget = tester.widget<TextField>(inputFinder);
      expect(textFieldWidget.controller?.text, isEmpty);

      // 6. Simulate keyboard closing (viewInsets.bottom = 0)
      await tester.pumpWidget(
        buildTestWidget(
          screenSize: screenSize,
          keyboardHeight: 0,
          child: PostCommentsSheet(
            postId: 10,
            token: 'valid_jwt_token',
            repository: mockRepo,
            notifier: notifier,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PostCommentsSheet: adapts cleanly on ultra-narrow/small screen with large keyboard without overflow',
    (tester) async {
      const smallScreen = Size(320, 480);
      const largeKeyboardHeight = 260.0;

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: smallScreen,
          keyboardHeight: largeKeyboardHeight,
          child: PostCommentsSheet(
            postId: 10,
            token: 'valid_jwt_token',
            repository: mockRepo,
            notifier: notifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    },
  );
}
