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
  int? lastParentCommentId;
  final List<int> replyRequests = [];
  final List<int> rootPageRequests = [];
  final List<(int rootId, int page)> replyPageRequests = [];
  final Map<int, List<PostCommentModel>> repliesByRoot = {};

  @override
  Future<PostCommentPage> getComments(
    int postId, {
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    rootPageRequests.add(page);
    final start = page * size;
    final end = (start + size).clamp(0, comments.length).toInt();
    final pageContent = start >= comments.length
        ? <PostCommentModel>[]
        : comments.sublist(start, end);
    return PostCommentPage(
      comments: pageContent,
      pageNumber: page,
      totalPages: (comments.length / size).ceil(),
      last: end >= comments.length,
    );
  }

  @override
  Future<PostCommentPage> getCommentReplies(
    int postId,
    int rootCommentId, {
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    replyRequests.add(rootCommentId);
    replyPageRequests.add((rootCommentId, page));
    final replies = repliesByRoot[rootCommentId] ?? [];
    final start = page * size;
    final end = (start + size).clamp(0, replies.length).toInt();
    final pageContent = start >= replies.length
        ? <PostCommentModel>[]
        : replies.sublist(start, end);
    return PostCommentPage(
      comments: pageContent,
      pageNumber: page,
      totalPages: (replies.length / size).ceil(),
      last: end >= replies.length,
    );
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
    lastParentCommentId = parentCommentId;
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
      parentCommentId: parentCommentId,
      rootCommentId: parentCommentId == null
          ? null
          : (repliesByRoot.entries
                    .where(
                      (entry) => entry.value.any(
                        (reply) => reply.commentId == parentCommentId,
                      ),
                    )
                    .map((entry) => entry.key)
                    .firstOrNull ??
                parentCommentId),
      createdAt: DateTime.now(),
    );
    if (parentCommentId != null) {
      final rootId = newComment.rootCommentId ?? parentCommentId;
      repliesByRoot.putIfAbsent(rootId, () => []).add(newComment);
    }
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
        home: Scaffold(body: child),
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
      expect(
        find.text('Bình luận số 1 rất dài để kiểm tra danh sách cuộn độc lập'),
        findsOneWidget,
      );
      expect(
        find.text('Bình luận số 2 chia sẻ kinh nghiệm du lịch thực tế'),
        findsOneWidget,
      );

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
      expect(
        mockRepo.lastCommentText,
        equals('Nội dung bình luận đang soạn thảo'),
      );

      // New comment appears in list and text field is cleared
      expect(
        find.text('Nội dung bình luận đang soạn thảo'),
        findsOneWidget,
      ); // now in comment card
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

  testWidgets('reply branches load only when opened and expand independently', (
    tester,
  ) async {
    final rootA = PostCommentModel(
      commentId: 1,
      postId: 10,
      content: 'Root A',
      author: const PostAuthorModel(userId: 2, handle: 'a', fullName: 'A'),
      replyCount: 1,
      createdAt: DateTime.now(),
    );
    final rootB = PostCommentModel(
      commentId: 2,
      postId: 10,
      content: 'Root B',
      author: const PostAuthorModel(userId: 3, handle: 'b', fullName: 'B'),
      replyCount: 1,
      createdAt: DateTime.now(),
    );
    mockRepo.comments = [rootA, rootB];
    mockRepo.repliesByRoot[1] = [
      PostCommentModel(
        commentId: 11,
        postId: 10,
        content: 'Reply A',
        author: const PostAuthorModel(userId: 4, handle: 'c', fullName: 'C'),
        parentCommentId: 1,
        rootCommentId: 1,
        createdAt: DateTime.now(),
      ),
    ];
    mockRepo.repliesByRoot[2] = [
      PostCommentModel(
        commentId: 22,
        postId: 10,
        content: 'Reply B',
        author: const PostAuthorModel(userId: 5, handle: 'd', fullName: 'D'),
        parentCommentId: 2,
        rootCommentId: 2,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      buildTestWidget(
        screenSize: const Size(360, 640),
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

    expect(mockRepo.replyRequests, isEmpty);
    expect(find.text('Reply A'), findsNothing);
    expect(find.text('Reply B'), findsNothing);

    await tester.tap(find.text('Xem 1 câu trả lời').first);
    await tester.pumpAndSettle();
    expect(mockRepo.replyRequests, [1]);
    expect(find.text('Reply A'), findsOneWidget);
    expect(find.text('Reply B'), findsNothing);

    final rootBReplies = find.text('Xem 1 câu trả lời').last;
    await tester.ensureVisible(rootBReplies);
    await tester.pumpAndSettle();
    await tester.tap(rootBReplies);
    await tester.pumpAndSettle();
    expect(mockRepo.replyRequests, [1, 2]);
    expect(find.text('Reply A'), findsOneWidget);
    expect(find.text('Reply B'), findsOneWidget);

    await tester.tap(find.text('Thu gọn câu trả lời').first);
    await tester.pumpAndSettle();
    expect(find.text('Reply A'), findsNothing);
    expect(find.text('Reply B'), findsOneWidget);

    await tester.tap(find.text('Xem 1 câu trả lời').first);
    await tester.pumpAndSettle();
    expect(find.text('Reply A'), findsOneWidget);
    expect(mockRepo.replyRequests, [1, 2]);
  });

  testWidgets(
    'replying to a post root previews the sent reply and keeps older replies collapsed',
    (tester) async {
      mockRepo.comments = [
        PostCommentModel(
          commentId: 1,
          postId: 10,
          content: 'Root with replies',
          author: const PostAuthorModel(userId: 2, handle: 'a', fullName: 'A'),
          replyCount: 1,
          createdAt: DateTime.now(),
        ),
      ];
      mockRepo.repliesByRoot[1] = [
        PostCommentModel(
          commentId: 11,
          postId: 10,
          content: 'Older reply',
          author: const PostAuthorModel(userId: 3, handle: 'b', fullName: 'B'),
          parentCommentId: 1,
          rootCommentId: 1,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(360, 640),
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
      expect(mockRepo.replyRequests, isEmpty);

      await tester.tap(find.byKey(const ValueKey('reply_comment_1')));
      await tester.pumpAndSettle();
      expect(mockRepo.replyRequests, isEmpty);
      expect(find.text('Older reply'), findsNothing);

      await tester.enterText(find.byType(TextField), 'My new reply');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('My new reply'), findsOneWidget);
      expect(find.text('Older reply'), findsNothing);
      expect(find.text('Xem 1 câu trả lời khác'), findsOneWidget);
      expect(mockRepo.replyRequests, isEmpty);

      await tester.tap(find.text('Xem 1 câu trả lời khác'));
      await tester.pumpAndSettle();
      expect(mockRepo.replyRequests, [1]);
      expect(find.text('My new reply'), findsOneWidget);
      expect(find.text('Older reply'), findsOneWidget);
    },
  );

  testWidgets(
    'replying to a nested community comment keeps the exact parent id',
    (tester) async {
      final root = PostCommentModel(
        commentId: 1,
        postId: 10,
        content: 'Root',
        author: const PostAuthorModel(userId: 2, handle: 'a', fullName: 'A'),
        replyCount: 1,
        createdAt: DateTime.now(),
      );
      final child = PostCommentModel(
        commentId: 11,
        postId: 10,
        content: 'Nested target',
        author: const PostAuthorModel(userId: 3, handle: 'b', fullName: 'B'),
        parentCommentId: 1,
        rootCommentId: 1,
        createdAt: DateTime.now(),
      );
      mockRepo.comments = [root];
      mockRepo.repliesByRoot[1] = [child];

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(360, 640),
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
      await tester.tap(find.text('Xem 1 câu trả lời'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reply_comment_11')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reply vào bình luận con');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(mockRepo.lastParentCommentId, 11);
      expect(find.text('Reply vào bình luận con'), findsOneWidget);
    },
  );

  testWidgets(
    'root comments and each reply thread paginate independently without duplicates',
    (tester) async {
      mockRepo.comments = List.generate(
        21,
        (index) => PostCommentModel(
          commentId: index + 1,
          postId: 10,
          content: 'Root $index',
          author: const PostAuthorModel(userId: 2, handle: 'a', fullName: 'A'),
          replyCount: index == 0 ? 21 : 0,
          createdAt: DateTime.now().add(Duration(seconds: index)),
        ),
      );
      mockRepo.repliesByRoot[1] = List.generate(
        21,
        (index) => PostCommentModel(
          commentId: 100 + index,
          postId: 10,
          content: 'Reply ${index + 1}',
          author: const PostAuthorModel(userId: 3, handle: 'b', fullName: 'B'),
          parentCommentId: 1,
          rootCommentId: 1,
          createdAt: DateTime.now().add(Duration(seconds: index)),
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(360, 640),
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
      expect(mockRepo.rootPageRequests, [0]);

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final loadMoreRoots = find.text('Xem thêm bình luận');
      await tester.tap(loadMoreRoots);
      await tester.pumpAndSettle();
      expect(mockRepo.rootPageRequests, [0, 1]);

      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      final firstRoot = find.text('Root 0');
      await tester.ensureVisible(firstRoot);
      await tester.pumpAndSettle();
      final openReplies = find.text('Xem 21 câu trả lời');
      await tester.ensureVisible(openReplies);
      await tester.pumpAndSettle();
      await tester.tap(openReplies);
      await tester.pumpAndSettle();
      expect(mockRepo.replyPageRequests, [(1, 0)]);

      final loadMoreReplies = find.text('Xem thêm câu trả lời');
      await tester.ensureVisible(loadMoreReplies);
      await tester.pumpAndSettle();
      await tester.tap(loadMoreReplies);
      await tester.pumpAndSettle();
      expect(mockRepo.replyPageRequests, [(1, 0), (1, 1)]);
      expect(find.text('Reply 21'), findsOneWidget);
    },
  );
}
