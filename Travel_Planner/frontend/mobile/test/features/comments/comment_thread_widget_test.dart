import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/comments/data/comments_repository.dart';
import 'package:mobile/features/comments/data/models/itinerary_comment.dart';
import 'package:mobile/features/comments/presentation/widgets/itinerary_comments_section.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';

class _ThreadRepository extends CommentsRepository {
  int? repliedTo;
  int rootReplyCount = 1;
  @override
  Future<PageResult<ItineraryComment>> getComments(
    int id, {
    int page = 0,
    int size = 10,
  }) async => PageResult(
    content: [
      ItineraryComment(
        commentId: 1,
        content: 'Bình luận gốc',
        replyCount: rootReplyCount,
        userId: 9,
      ),
    ],
    pageNumber: 0,
    pageSize: 10,
    totalElements: 1,
    totalPages: 1,
    isLast: true,
  );

  @override
  Future<PageResult<ItineraryComment>> getActivityComments(
    int id, {
    int page = 0,
    int size = 10,
  }) => getComments(id, page: page, size: size);

  @override
  Future<PageResult<ItineraryComment>> getReplies(
    int id, {
    int page = 0,
    int size = 10,
  }) async => PageResult(
    content: const [
      ItineraryComment(
        commentId: 2,
        content: 'Câu trả lời',
        parentCommentId: 1,
        rootCommentId: 1,
      ),
    ],
    pageNumber: 0,
    pageSize: 10,
    totalElements: 1,
    totalPages: 1,
    isLast: true,
  );
  @override
  Future<ItineraryComment> createReply(
    int id, {
    required String content,
    required String token,
  }) async {
    repliedTo = id;
    return ItineraryComment(
      commentId: 3,
      content: content,
      parentCommentId: id,
      rootCommentId: 1,
    );
  }
}

void main() {
  testWidgets('mở và thu gọn reply ngay dưới comment gốc', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItineraryCommentsSection(
            itineraryId: 1,
            repository: _ThreadRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Câu trả lời'), findsNothing);
    await tester.tap(find.text('Xem 1 câu trả lời'));
    await tester.pumpAndSettle();
    expect(find.text('Câu trả lời'), findsOneWidget);
    await tester.tap(find.text('Thu gọn câu trả lời'));
    await tester.pumpAndSettle();
    expect(find.text('Câu trả lời'), findsNothing);
  });

  testWidgets(
    'reply trực tiếp hiện ngay nhưng giữ các reply cũ thu gọn đến khi bấm xem',
    (tester) async {
      final repository = _ThreadRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryCommentsSection(
              itineraryId: 1,
              token: 'test-token',
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trả lời').first);
      await tester.pumpAndSettle();

      expect(find.text('Câu trả lời'), findsNothing);
      expect(find.textContaining('Đang trả lời'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField), 'Reply của tôi');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();

      expect(find.text('Reply của tôi'), findsOneWidget);
      expect(find.text('Câu trả lời'), findsNothing);
      expect(find.text('Xem 1 câu trả lời khác'), findsOneWidget);

      await tester.tap(find.text('Xem 1 câu trả lời khác'));
      await tester.pumpAndSettle();
      expect(find.text('Reply của tôi'), findsOneWidget);
      expect(find.text('Câu trả lời'), findsOneWidget);
    },
  );

  testWidgets('activity comment giữ reply cũ thu gọn sau khi gửi reply gốc', (
    tester,
  ) async {
    final repository = _ThreadRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: ActivityCommentsSection(
              activityId: 1,
              token: 'test-token',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trả lời').first);
    await tester.pumpAndSettle();
    expect(find.text('Câu trả lời'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Reply hoạt động mới');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gửi bình luận'));
    await tester.pumpAndSettle();

    expect(find.text('Reply hoạt động mới'), findsOneWidget);
    expect(find.text('Câu trả lời'), findsNothing);
    expect(find.text('Xem 1 câu trả lời khác'), findsOneWidget);
  });

  testWidgets('composer hoạt động nằm dưới thread và hiện ngữ cảnh trả lời', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: ActivityCommentsSection(
              activityId: 1,
              token: 'test-token',
              repository: _ThreadRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trả lời').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang trả lời @'), findsOneWidget);
    expect(find.text('Trả lời @Người dùng…'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      greaterThan(tester.getTopLeft(find.text('Bình luận gốc')).dy),
    );
  });

  testWidgets(
    'gửi khi trả lời một reply vẫn dùng commentId của reply làm parent',
    (tester) async {
      final repository = _ThreadRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryCommentsSection(
              itineraryId: 1,
              token: 'test-token',
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem 1 câu trả lời'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trả lời').last);
      await tester.pump();
      expect(find.textContaining('Đang trả lời'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Câu trả lời sâu');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi bình luận'));
      await tester.pumpAndSettle();
      expect(repository.repliedTo, 2);
      expect(find.text('Câu trả lời sâu'), findsOneWidget);
    },
  );
}
