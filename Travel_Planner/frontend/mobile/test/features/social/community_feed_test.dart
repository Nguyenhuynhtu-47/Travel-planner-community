import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/social/data/community_post_repository.dart';
import 'package:mobile/features/social/data/models/post_comment_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/presentation/community_feed_notifier.dart';
import 'package:mobile/features/social/presentation/screens/community_feed_screen.dart';
import 'package:mobile/features/social/presentation/screens/create_post_screen.dart';
import 'package:mobile/features/social/presentation/widgets/post_card_widget.dart';
import 'package:mobile/features/social/presentation/widgets/post_comments_sheet.dart';
import 'package:mobile/features/social/presentation/widgets/report_post_dialog.dart';

class MockCommunityPostRepository extends CommunityPostRepository {
  List<PostModel> publicFeedToReturn = [];
  List<PostModel> followingFeedToReturn = [];
  List<PostCommentModel> commentsToReturn = [];
  int likeCallCount = 0;
  int unlikeCallCount = 0;
  bool shouldFailLike = false;
  int reportCallCount = 0;
  String? lastReportReason;
  int addCommentCallCount = 0;
  String? lastCommentContent;
  int deleteCommentCallCount = 0;
  int createPostCallCount = 0;
  String? lastCreatedContent;

  @override
  Future<List<PostModel>> getPublicFeed({int page = 0, int size = 10, String? token}) async {
    return publicFeedToReturn;
  }

  @override
  Future<List<PostModel>> getFollowingFeed({int page = 0, int size = 10, required String token}) async {
    return followingFeedToReturn;
  }

  @override
  Future<void> likePost(int postId, {required String token}) async {
    likeCallCount++;
    if (shouldFailLike) {
      throw Exception('Server error liking post');
    }
  }

  @override
  Future<void> unlikePost(int postId, {required String token}) async {
    unlikeCallCount++;
    if (shouldFailLike) {
      throw Exception('Server error unliking post');
    }
  }

  @override
  Future<List<PostCommentModel>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    return commentsToReturn;
  }

  @override
  Future<PostCommentModel> addComment(
    int postId, {
    required String content,
    required String token,
  }) async {
    addCommentCallCount++;
    lastCommentContent = content;
    return PostCommentModel(
      commentId: 888,
      postId: postId,
      content: content,
      author: const PostAuthorModel(userId: 100, handle: 'traveler_bob', fullName: 'Bob Traveler'),
      isOwner: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteComment(int postId, int commentId, {required String token}) async {
    deleteCommentCallCount++;
  }

  @override
  Future<PostModel> createPost({
    required String content,
    String visibility = 'PUBLIC',
    List<int>? mediaAssetIds,
    int? itineraryId,
    required String token,
  }) async {
    createPostCallCount++;
    lastCreatedContent = content;
    return PostModel(
      postId: 999,
      content: content,
      author: const PostAuthorModel(userId: 100, handle: 'traveler_bob', fullName: 'Bob Traveler'),
      mediaUrls: const [],
      mediaAssetIds: mediaAssetIds ?? const [],
      visibility: visibility,
      status: 'ACTIVE',
      likeCount: 0,
      commentCount: 0,
      isLikedByMe: false,
      isOwner: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> reportPost(int postId, {required String reason, String? details, required String token}) async {
    reportCallCount++;
    lastReportReason = reason;
  }

  @override
  Future<int> getTotalUnread({required String token}) async {
    return 3;
  }
}

class FakeTestAuthNotifier extends AuthNotifier {
  final bool authenticated;
  final int userId;
  final String username;

  FakeTestAuthNotifier({
    this.authenticated = true,
    this.userId = 100,
    this.username = 'traveler_bob',
  });

  @override
  bool get isAuthenticated => authenticated;

  @override
  String? get token => authenticated ? 'fake-jwt-token' : null;
}

void main() {
  group('Phase 6B - PostModel serialization', () {
    test('parses post with media and active attached itinerary correctly', () {
      final json = {
        'postId': 1,
        'content': 'Khám phá Đà Lạt tuyệt đẹp!',
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
        'likeCount': 10,
        'commentCount': 4,
        'isLikedByMe': true,
        'isOwner': true,
        'createdAt': '2026-11-12T10:00:00Z',
        'author': {
          'userId': 100,
          'handle': 'traveler_bob',
          'fullName': 'Bob Traveler',
          'avatar': 'https://example.com/avatar.jpg',
        },
        'mediaUrls': ['https://example.com/photo1.jpg'],
        'mediaAssetIds': [10],
        'itinerary': {
          'itineraryId': 50,
          'title': 'Chuyến đi Đà Lạt 3N2Đ',
          'location': 'Đà Lạt, Lâm Đồng',
          'totalDays': 3,
          'totalActivities': 8,
          'coverImage': 'https://example.com/cover.jpg',
        },
        'itineraryUnavailable': false,
        'itineraryUnavailableReason': null,
      };

      final post = PostModel.fromJson(json);

      expect(post.postId, 1);
      expect(post.content, 'Khám phá Đà Lạt tuyệt đẹp!');
      expect(post.likeCount, 10);
      expect(post.commentCount, 4);
      expect(post.isLikedByMe, true);
      expect(post.isOwner, true);
      expect(post.author.handle, 'traveler_bob');
      expect(post.mediaUrls.length, 1);
      expect(post.mediaUrls.first, 'https://example.com/photo1.jpg');
      expect(post.itinerary, isNotNull);
      expect(post.itinerary!.title, 'Chuyến đi Đà Lạt 3N2Đ');
      expect(post.itineraryUnavailable, false);
    });

    test('parses post with fallback unavailable itinerary correctly', () {
      final json = {
        'postId': 2,
        'content': 'Bài viết với lịch trình bị ẩn',
        'visibility': 'PUBLIC',
        'status': 'ACTIVE',
        'likeCount': 2,
        'commentCount': 0,
        'isLikedByMe': false,
        'isOwner': false,
        'createdAt': '2026-11-12T11:00:00Z',
        'author': {
          'userId': 200,
          'handle': 'alice',
          'fullName': 'Alice Wonderland',
        },
        'mediaUrls': [],
        'mediaAssetIds': [],
        'itinerary': null,
        'itineraryUnavailable': true,
        'itineraryUnavailableReason': 'UNAVAILABLE',
      };

      final post = PostModel.fromJson(json);

      expect(post.postId, 2);
      expect(post.itinerary, isNull);
      expect(post.itineraryUnavailable, true);
      expect(post.itineraryUnavailableReason, 'UNAVAILABLE');
    });

    test('parses PostCommentModel correctly', () {
      final json = {
        'commentId': 77,
        'postId': 1,
        'content': 'Bài viết rất hữu ích!',
        'isOwner': false,
        'createdAt': '2026-11-12T12:00:00Z',
        'author': {
          'userId': 300,
          'handle': 'charlie',
          'fullName': 'Charlie Nguyen',
        },
      };

      final comment = PostCommentModel.fromJson(json);

      expect(comment.commentId, 77);
      expect(comment.postId, 1);
      expect(comment.content, 'Bài viết rất hữu ích!');
      expect(comment.author.handle, 'charlie');
      expect(comment.isOwner, false);
    });
  });

  group('Phase 6B - CommunityFeedNotifier', () {
    late MockCommunityPostRepository repo;
    late CommunityFeedNotifier notifier;

    setUp(() {
      repo = MockCommunityPostRepository();
      notifier = CommunityFeedNotifier(repository: repo);
    });

    test('loadPublic populates posts and deduplicates', () async {
      final sample = PostModel(
        postId: 101,
        content: 'Post 101',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        likeCount: 5,
        commentCount: 1,
        isLikedByMe: false,
        isOwner: false,
        createdAt: DateTime.now(),
        mediaUrls: const [],
        mediaAssetIds: const [],
        author: const PostAuthorModel(userId: 1, handle: 'user1', fullName: 'User 1'),
      );

      repo.publicFeedToReturn = [sample, sample]; // Duplicate in response

      await notifier.loadPublic(null, refresh: true);

      expect(notifier.publicPosts.length, 1);
      expect(notifier.publicPosts.first.postId, 101);
      expect(notifier.isLoading, false);
    });

    test('toggleLike optimistically increments and rollbacks on failure', () async {
      final post = PostModel(
        postId: 102,
        content: 'Post 102',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        likeCount: 5,
        commentCount: 0,
        isLikedByMe: false,
        isOwner: false,
        createdAt: DateTime.now(),
        mediaUrls: const [],
        mediaAssetIds: const [],
        author: const PostAuthorModel(userId: 1, handle: 'user1', fullName: 'User 1'),
      );

      repo.publicFeedToReturn = [post];
      await notifier.loadPublic(null, refresh: true);

      // Successful like
      repo.shouldFailLike = false;
      await notifier.toggleLike(102, 'valid-token');
      expect(notifier.publicPosts.first.isLikedByMe, true);
      expect(notifier.publicPosts.first.likeCount, 6);

      // Failed unlike -> should rollback
      repo.shouldFailLike = true;
      await notifier.toggleLike(102, 'valid-token');
      // Rolled back to previous state
      expect(notifier.publicPosts.first.isLikedByMe, true);
      expect(notifier.publicPosts.first.likeCount, 6);
    });

    test('updateCommentCount and removePost modify list dynamically', () async {
      final post = PostModel(
        postId: 103,
        content: 'Post 103',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        likeCount: 0,
        commentCount: 2,
        isLikedByMe: false,
        isOwner: false,
        createdAt: DateTime.now(),
        mediaUrls: const [],
        mediaAssetIds: const [],
        author: const PostAuthorModel(userId: 1, handle: 'user1', fullName: 'User 1'),
      );

      repo.publicFeedToReturn = [post];
      await notifier.loadPublic(null, refresh: true);

      notifier.updateCommentCount(103, 1);
      expect(notifier.publicPosts.first.commentCount, 3);

      notifier.updateCommentCount(103, -2);
      expect(notifier.publicPosts.first.commentCount, 1);

      notifier.removePost(103);
      expect(notifier.publicPosts.isEmpty, true);
    });
  });

  group('Phase 6B - PostCardWidget', () {
    testWidgets('renders author, content, and attached itinerary card', (tester) async {
      final post = PostModel(
        postId: 201,
        content: 'Lịch trình Phú Quốc siêu đẹp',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        likeCount: 15,
        commentCount: 3,
        isLikedByMe: false,
        isOwner: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        mediaUrls: const [],
        mediaAssetIds: const [],
        author: const PostAuthorModel(
          userId: 50,
          handle: 'phuquoc_lover',
          fullName: 'Phú Quốc Lover',
        ),
        itinerary: const PostItineraryModel(
          itineraryId: 301,
          title: 'Khám phá Bắc Đảo 3 ngày',
          location: 'Phú Quốc, Kiên Giang',
          totalDays: 3,
        ),
      );

      bool likeTapped = false;
      bool itineraryTapped = false;
      int? tappedItineraryId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PostCardWidget(
              post: post,
              onLike: () => likeTapped = true,
              onItineraryTap: (id) {
                itineraryTapped = true;
                tappedItineraryId = id;
              },
            ),
          ),
        ),
      );

      expect(find.text('Phú Quốc Lover'), findsOneWidget);
      expect(find.text('@phuquoc_lover'), findsOneWidget);
      expect(find.text('Lịch trình Phú Quốc siêu đẹp'), findsOneWidget);
      expect(find.text('Khám phá Bắc Đảo 3 ngày'), findsOneWidget);
      expect(find.text('3 ngày'), findsOneWidget);
      expect(find.text('Phú Quốc, Kiên Giang'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(likeTapped, true);

      await tester.tap(find.text('Khám phá Bắc Đảo 3 ngày'));
      await tester.pump();
      expect(itineraryTapped, true);
      expect(tappedItineraryId, 301);
    });

    testWidgets('renders fallback banner when itineraryUnavailable is true', (tester) async {
      final post = PostModel(
        postId: 202,
        content: 'Lịch trình bí mật',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        likeCount: 0,
        commentCount: 0,
        isLikedByMe: false,
        isOwner: false,
        createdAt: DateTime.now(),
        mediaUrls: const [],
        mediaAssetIds: const [],
        author: const PostAuthorModel(
          userId: 51,
          handle: 'secret_user',
          fullName: 'Secret User',
        ),
        itineraryUnavailable: true,
        itineraryUnavailableReason: 'UNAVAILABLE',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PostCardWidget(post: post),
          ),
        ),
      );

      expect(find.text('Lịch trình không khả dụng'), findsOneWidget);
      expect(
        find.text('Lịch trình đính kèm đã bị xóa, đặt về riêng tư hoặc không còn khả dụng.'),
        findsOneWidget,
      );
    });
  });

  group('Phase 6B - ReportPostDialog', () {
    testWidgets('allows selecting a reason and submitting report', (tester) async {
      final repo = MockCommunityPostRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => ReportPostDialog(
                    postId: 99,
                    token: 'valid-token',
                    repository: repo,
                  ),
                ),
                child: const Text('Báo cáo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo bài viết'), findsOneWidget);
      expect(find.text('Nội dung phản cảm hoặc khiêu dâm'), findsOneWidget);

      // Tap on a reason
      await tester.tap(find.text('Nội dung phản cảm hoặc khiêu dâm'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();

      expect(repo.reportCallCount, 1);
      expect(repo.lastReportReason, 'Nội dung phản cảm hoặc khiêu dâm');
    });
  });

  group('Phase 6B - CommunityFeedScreen', () {
    testWidgets('renders TabBar with 2 tabs and AppBar shortcuts', (tester) async {
      final repo = MockCommunityPostRepository();
      final auth = FakeTestAuthNotifier(authenticated: true);
      final notifier = CommunityFeedNotifier(repository: repo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CommunityFeedScreen(
            authNotifier: auth,
            notifier: notifier,
            repository: repo,
          ),
        ),
      );

      expect(find.text('Cộng đồng du lịch'), findsOneWidget);
      expect(find.text('Dành cho bạn'), findsOneWidget);
      expect(find.text('Đang theo dõi'), findsOneWidget);
      expect(find.byTooltip('Tin nhắn'), findsOneWidget);
      expect(find.byTooltip('Bạn bè & Lời mời'), findsOneWidget);
      expect(find.byTooltip('Thông báo'), findsOneWidget);
      expect(find.text('Đăng bài'), findsOneWidget);
    });
  });

  group('Phase 6B - PostCommentsSheet', () {
    testWidgets('renders flat comments list and submits new comment', (tester) async {
      final repo = MockCommunityPostRepository();
      final notifier = CommunityFeedNotifier(repository: repo);

      repo.commentsToReturn = [
        PostCommentModel(
          commentId: 101,
          postId: 1,
          content: 'Lịch trình hay quá!',
          author: const PostAuthorModel(
            userId: 2,
            handle: 'traveler_cat',
            fullName: 'Cat Traveler',
          ),
          isOwner: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PostCommentsSheet(
              postId: 1,
              token: 'test-token',
              repository: repo,
              notifier: notifier,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bình luận'), findsOneWidget);
      expect(find.text('Lịch trình hay quá!'), findsOneWidget);
      expect(find.text('Cat Traveler'), findsOneWidget);

      // Enter a new comment
      await tester.enterText(find.byType(TextField), 'Đồng ý, rất bổ ích!');
      await tester.pump();

      // Submit comment
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(repo.addCommentCallCount, 1);
      expect(repo.lastCommentContent, 'Đồng ý, rất bổ ích!');
      expect(find.text('Đồng ý, rất bổ ích!'), findsOneWidget);
    });
  });

  group('Phase 6B - CreatePostScreen', () {
    testWidgets('renders input fields, visibility selector, and submits post', (tester) async {
      final repo = MockCommunityPostRepository();
      final auth = FakeTestAuthNotifier(authenticated: true);
      final notifier = CommunityFeedNotifier(repository: repo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CreatePostScreen(
            authNotifier: auth,
            repository: repo,
            notifier: notifier,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tạo bài viết'), findsOneWidget);
      expect(find.text('Công khai'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Enter content
      await tester.enterText(
        find.byType(TextField),
        'Chuyến đi Vũng Tàu cuối tuần tuyệt vời!',
      );
      await tester.pump();

      // Tap Đăng
      await tester.tap(find.text('Đăng'));
      await tester.pumpAndSettle();

      expect(repo.createPostCallCount, 1);
      expect(repo.lastCreatedContent, 'Chuyến đi Vũng Tàu cuối tuần tuyệt vời!');
    });
  });
}
