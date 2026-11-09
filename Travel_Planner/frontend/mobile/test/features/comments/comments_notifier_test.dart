import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/comments/data/comments_repository.dart';
import 'package:mobile/features/comments/data/models/itinerary_comment.dart';
import 'package:mobile/features/comments/presentation/comments_notifier.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';

class _CommentsRepository extends CommentsRepository {
  final Map<int, List<ItineraryComment>> activityRoots = {};
  int? repliedTo;
  int _replyPage = 0;
  int get lastReplyPage => _replyPage;
  @override
  Future<PageResult<ItineraryComment>> getComments(int itineraryId, {int page = 0, int size = 10}) async => _page(const [], page, true);
  @override
  Future<PageResult<ItineraryComment>> getActivityComments(int activityId, {int page = 0, int size = 10}) async => _page(activityRoots[activityId] ?? [], page, true);
  @override
  Future<PageResult<ItineraryComment>> getReplies(int commentId, {int page = 0, int size = 10}) async {
    _replyPage = page;
    final values = page == 0 ? [_comment(8, root: 5, parent: 5)] : [_comment(8, root: 5, parent: 5), _comment(9, root: 5, parent: 8)];
    return _page(values, page, page > 0);
  }
  @override
  Future<ItineraryComment> createReply(int commentId, {required String content, required String token}) async {
    repliedTo = commentId;
    return _comment(20, root: 5, parent: commentId);
  }
  PageResult<ItineraryComment> _page(List<ItineraryComment> values, int page, bool last) => PageResult(
    content: values, pageNumber: page, pageSize: 10, totalElements: values.length, totalPages: last ? page + 1 : page + 2, isLast: last);
  ItineraryComment _comment(int id, {int? root, int? parent}) => ItineraryComment(commentId: id, content: 'c$id', rootCommentId: root, parentCommentId: parent);
}

void main() {
  test('reply to a reply keeps its immediate parent and does not create a root', () async {
    final repository = _CommentsRepository();
    final notifier = CommentsNotifier(itineraryId: 1, repository: repository);
    notifier.comments.add(ItineraryComment(commentId: 5, content: 'root', replyCount: 1));
    await notifier.loadReplies(5);
    expect(await notifier.submit('deeper reply', 'token', parentCommentId: 8), isTrue);
    expect(repository.repliedTo, 8);
    expect(notifier.comments.map((comment) => comment.commentId), [5]);
    expect(notifier.replies[5]!.last.parentCommentId, 8);
    notifier.dispose();
  });

  test('reply pagination deduplicates overlapping items and preserves server order', () async {
    final repository = _CommentsRepository();
    final notifier = CommentsNotifier(itineraryId: 1, repository: repository);
    await notifier.loadReplies(5);
    await notifier.loadReplies(5);
    expect(repository.lastReplyPage, 1);
    expect(notifier.replies[5]!.map((comment) => comment.commentId), [8, 9]);
    notifier.dispose();
  });

  test('activity notifier is scoped to its activity', () async {
    final repository = _CommentsRepository()
      ..activityRoots[1] = [ItineraryComment(commentId: 1, content: 'A')]
      ..activityRoots[2] = [ItineraryComment(commentId: 2, content: 'B')];
    final a = CommentsNotifier.forActivity(activityId: 1, repository: repository);
    final b = CommentsNotifier.forActivity(activityId: 2, repository: repository);
    await a.load(); await b.load();
    expect(a.comments.single.commentId, 1);
    expect(b.comments.single.commentId, 2);
    a.dispose(); b.dispose();
  });
}
