import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/profile/data/models/public_profile.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/profile/data/public_profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/public_profile_screen.dart';
import 'package:mobile/features/social/data/community_post_repository.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/presentation/widgets/post_card_widget.dart';

class MockAuthNotifier extends AuthNotifier {
  final Map<String, dynamic>? _user;
  final bool _authenticated;

  MockAuthNotifier({Map<String, dynamic>? user, this._authenticated = true})
      : _user = user ?? {'userId': 100, 'username': 'current_user', 'avatar': ''};

  @override
  String? get token => _authenticated ? 'valid_test_token' : null;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  Map<String, dynamic>? get currentUser => _user;
}

class MockProfileRepo extends ProfileRepository {
  final Map<String, dynamic> data;
  MockProfileRepo(this.data);

  @override
  Future<Map<String, dynamic>> getProfile(String token) async => data;

  @override
  Future<List<ItinerarySummary>> getMyItineraries(String token) async => [];
}

class MockPublicProfileRepo extends PublicProfileRepository {
  final PublicProfile profile;
  final List<ItinerarySummary> itinerariesList;
  MockPublicProfileRepo(this.profile, this.itinerariesList);

  @override
  Future<PublicProfile> getProfile(int userId, {String? token}) async => profile;

  @override
  Future<PageResult<ItinerarySummary>> itineraries(
    int userId, {
    int page = 0,
    int size = 10,
    String? token,
  }) async =>
      PageResult(
        content: itinerariesList,
        pageNumber: page,
        pageSize: size,
        totalElements: itinerariesList.length,
        totalPages: 1,
        isLast: true,
      );
}

class MockCommunityPostRepo extends CommunityPostRepository {
  final List<PostModel> myPostsList;
  final List<PostModel> userPostsList;
  MockCommunityPostRepo({
    this.myPostsList = const [],
    this.userPostsList = const [],
  });

  @override
  Future<List<PostModel>> getMyPosts({
    int page = 0,
    int size = 10,
    String? token,
  }) async =>
      myPostsList;

  @override
  Future<List<PostModel>> getUserPosts(
    int userId, {
    int page = 0,
    int size = 10,
    String? token,
  }) async =>
      userPostsList;
}

PostModel makeTestPost({
  required int id,
  required int authorId,
  String content = 'Test post content',
  List<String> mediaUrls = const [],
  bool isOwner = false,
}) {
  return PostModel(
    postId: id,
    content: content,
    visibility: 'PUBLIC',
    likeCount: 5,
    commentCount: 2,
    isLikedByMe: false,
    isOwner: isOwner,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    author: PostAuthorModel(
      userId: authorId,
      fullName: 'Author $authorId',
      handle: 'handle$authorId',
      avatar: null,
    ),
    mediaUrls: mediaUrls,
    mediaAssetIds: const [],
  );
}

ItinerarySummary makeTestSummary({required int id, required int creatorId}) {
  return ItinerarySummary(
    itineraryId: id,
    title: 'Itinerary $id',
    location: 'Da Lat',
    totalDays: 3,
    budget: 2000000,
    viewCount: 10,
    favoriteCount: 5,
    ratingCount: 2,
    averageRating: 4.5,
    creator: CreatorSummary(
      userId: creatorId,
      username: 'creator$creatorId',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1: PostCardWidget Layout and Aspect Ratios', () {
    testWidgets('Single photo has 4/3 AspectRatio', (tester) async {
      final post = makeTestPost(
        id: 1,
        authorId: 100,
        mediaUrls: ['https://example.com/photo1.jpg'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PostCardWidget(post: post),
          ),
        ),
      );

      final aspectFinder = find.byWidgetPredicate(
        (w) => w is AspectRatio && (w.aspectRatio - (4 / 3)).abs() < 0.01,
      );
      expect(aspectFinder, findsOneWidget);
    });

    testWidgets('2 photos have 3/2 AspectRatio and 3 photos have 4/3 AspectRatio', (tester) async {
      final post2 = makeTestPost(
        id: 2,
        authorId: 100,
        mediaUrls: [
          'https://example.com/p1.jpg',
          'https://example.com/p2.jpg',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCardWidget(post: post2),
            ),
          ),
        ),
      );

      final aspectFinder2 = find.byWidgetPredicate(
        (w) => w is AspectRatio && (w.aspectRatio - (3 / 2)).abs() < 0.01,
      );
      expect(aspectFinder2, findsOneWidget);

      final post3 = makeTestPost(
        id: 3,
        authorId: 100,
        mediaUrls: [
          'https://example.com/p1.jpg',
          'https://example.com/p2.jpg',
          'https://example.com/p3.jpg',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCardWidget(post: post3),
            ),
          ),
        ),
      );

      final aspectFinder3 = find.byWidgetPredicate(
        (w) => w is AspectRatio && (w.aspectRatio - (4 / 3)).abs() < 0.01,
      );
      expect(aspectFinder3, findsOneWidget);
    });

    testWidgets('PostCardWidget default margin is horizontal 12, vertical 6', (tester) async {
      final post = makeTestPost(id: 1, authorId: 100);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PostCardWidget(post: post),
          ),
        ),
      );

      final containerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.margin is EdgeInsets) {
          final m = w.margin as EdgeInsets;
          return m.left == 12 && m.right == 12 && m.top == 6 && m.bottom == 6;
        }
        return false;
      });
      expect(containerFinder, findsOneWidget);
    });
  });

  group('Requirement 2: ProfileScreen Scroll Architecture', () {
    testWidgets('ProfileScreen uses NestedScrollView with ProfileTabBarDelegate pinned header', (tester) async {
      final auth = MockAuthNotifier(user: {'userId': 100, 'username': 'testuser'});
      final profileRepo = MockProfileRepo({
        'userId': 100,
        'fullName': 'Nguyen Van A',
        'handle': 'nguyenvana',
        'bio': 'Travel enthusiast',
        'role': 'USER',
        'status': 'ACTIVE',
        'avatar': '',
      });
      final postRepo = MockCommunityPostRepo(
        myPostsList: [
          makeTestPost(id: 10, authorId: 100, content: 'Bài viết cá nhân 10', isOwner: true),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            authNotifier: auth,
            repository: profileRepo,
            postRepository: postRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NestedScrollView), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
      expect(find.text('Lịch trình'), findsOneWidget);
      expect(find.text('Bài viết'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);

      // Tap "Bài viết" tab
      await tester.tap(find.text('Bài viết'));
      await tester.pumpAndSettle();

      expect(find.text('Bài viết cá nhân 10'), findsOneWidget);
    });
  });

  group('Requirement 3: PublicProfileScreen Tabs and Posts', () {
    testWidgets('PublicProfileScreen renders NestedScrollView, TabBar, and both tabs', (tester) async {
      final auth = MockAuthNotifier(user: {'userId': 999, 'username': 'current_user'});
      const publicProfile = PublicProfile(
        userId: 200,
        username: 'otheruser',
        handle: 'otheruser',
        fullName: 'Tran Van B',
        avatar: null,
        bio: 'Exploring Vietnam',
        isFollowing: false,
        isOwnProfile: false,
        followerCount: 42,
        followingCount: 15,
      );

      final mockPublicRepo = MockPublicProfileRepo(
        publicProfile,
        [makeTestSummary(id: 50, creatorId: 200)],
      );

      final mockPostRepo = MockCommunityPostRepo(
        userPostsList: [
          makeTestPost(
            id: 88,
            authorId: 200,
            content: 'Bài viết của Tran Van B',
            isOwner: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PublicProfileScreen(
            userId: 200,
            authNotifier: auth,
            repository: mockPublicRepo,
            postRepository: mockPostRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify NestedScrollView exists
      expect(find.byType(NestedScrollView), findsOneWidget);

      // Verify header info
      expect(find.text('Tran Van B'), findsWidgets);
      expect(find.text('@otheruser'), findsOneWidget);
      expect(find.text('Exploring Vietnam'), findsOneWidget);

      // Verify both tabs exist
      expect(find.text('Lịch trình'), findsOneWidget);
      expect(find.text('Bài viết'), findsOneWidget);

      // Tab 0 shows Itinerary
      expect(find.text('Itinerary 50'), findsOneWidget);

      // Switch to Tab 1: "Bài viết"
      await tester.tap(find.text('Bài viết'));
      await tester.pumpAndSettle();

      // Tab 1 shows other user's post
      expect(find.text('Bài viết của Tran Van B'), findsOneWidget);
    });

    testWidgets('Viewer cannot edit or delete another user post on PublicProfileScreen', (tester) async {
      final auth = MockAuthNotifier(user: {'userId': 999, 'username': 'current_user'});
      const publicProfile = PublicProfile(
        userId: 200,
        username: 'otheruser',
        handle: 'otheruser',
        fullName: 'Tran Van B',
        avatar: null,
        bio: null,
        isFollowing: false,
        isOwnProfile: false,
        followerCount: 0,
        followingCount: 0,
      );

      final mockPublicRepo = MockPublicProfileRepo(publicProfile, []);
      final mockPostRepo = MockCommunityPostRepo(
        userPostsList: [
          makeTestPost(
            id: 99,
            authorId: 200,
            content: 'Post by someone else',
            isOwner: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PublicProfileScreen(
            userId: 200,
            authNotifier: auth,
            repository: mockPublicRepo,
            postRepository: mockPostRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to posts tab
      await tester.tap(find.text('Bài viết'));
      await tester.pumpAndSettle();

      expect(find.text('Post by someone else'), findsOneWidget);

      // Tap options menu icon
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // "Chỉnh sửa bài viết" and "Xóa bài viết" MUST NOT be present
      expect(find.text('Chỉnh sửa bài viết'), findsNothing);
      expect(find.text('Xóa bài viết'), findsNothing);

      // Only "Báo cáo bài viết" should be present
      expect(find.text('Báo cáo bài viết'), findsOneWidget);
    });
  });
}
