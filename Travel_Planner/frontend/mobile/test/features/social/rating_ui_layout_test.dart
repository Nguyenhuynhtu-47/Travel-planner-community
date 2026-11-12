import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/comments/presentation/widgets/itinerary_comments_section.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/social/data/social_repository.dart';

class MockSocialRepository extends SocialRepository {
  int rateCalls = 0;
  int deleteRatingCalls = 0;
  int lastScore = 0;

  @override
  Future<Map<String, dynamic>> rateItinerary(
    int itineraryId,
    int score, {
    String? token,
  }) async {
    rateCalls++;
    lastScore = score;
    return {
      'score': score,
      'averageRating': score.toDouble(),
      'ratingCount': 1,
    };
  }

  @override
  Future<void> deleteRating(int itineraryId, {String? token}) async {
    deleteRatingCalls++;
  }
}

class FakeTestAuthNotifier extends AuthNotifier {
  final bool authenticated;
  final int userId;
  final String username;

  FakeTestAuthNotifier({
    this.authenticated = true,
    this.userId = 99,
    this.username = 'test_traveler',
  });

  @override
  bool get isAuthenticated => authenticated;

  @override
  String? get token => authenticated ? 'fake_jwt_token' : null;

  @override
  Map<String, dynamic>? get currentUser =>
      authenticated ? {'userId': userId, 'username': username} : null;
}

class FakeItineraryDetailNotifier extends ItineraryDetailNotifier {
  final ItineraryDetail _detail;

  FakeItineraryDetailNotifier({
    required super.itineraryId,
    required ItineraryDetail detail,
  })  : _detail = detail,
        super(initialDetail: detail) {
    itineraryDetail = detail;
    isLoading = false;
  }

  @override
  Future<void> loadDetail({String? token}) async {
    itineraryDetail = _detail;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}

ItineraryDetail buildTestDetail({
  int id = 501,
  String title = 'Khám phá Mộc Châu 3 ngày 2 đêm',
  int creatorUserId = 10,
  int? userRating,
  int ratingCount = 0,
  double averageRating = 0.0,
  List<ItineraryDayDetail> days = const [],
}) {
  return ItineraryDetail(
    itineraryId: id,
    title: title,
    location: 'Sơn La',
    totalDays: days.isEmpty ? 1 : days.length,
    budget: 1500000,
    viewCount: 25,
    favoriteCount: 10,
    ratingCount: ratingCount,
    averageRating: averageRating,
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    days: days,
    isFavorited: false,
    isSaved: false,
    userRating: userRating,
    creator: CreatorSummary(userId: creatorUserId, username: 'mock_author'),
  );
}

void main() {
  group('1. Rating Dialog - Layout & RenderFlex Overflow Prevention', () {
    testWidgets('Dialog renders cleanly without RenderFlex overflow on standard 360x640 screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSocial = MockSocialRepository();
      final detail = buildTestDetail(userRating: 4, ratingCount: 3, averageRating: 4.3);
      final fakeNotifier = FakeItineraryDetailNotifier(
        itineraryId: detail.itineraryId,
        detail: detail,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: detail.itineraryId,
              initialDetail: detail,
              notifier: fakeNotifier,
              socialRepository: mockSocial,
              authNotifier: FakeTestAuthNotifier(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to rating section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      final editBtnFinder = find.text('Chỉnh sửa');
      expect(editBtnFinder, findsOneWidget);
      await tester.tap(editBtnFinder);
      await tester.pumpAndSettle();

      // Verify Dialog is displayed
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cập nhật đánh giá'), findsOneWidget);
      expect(find.text('Chọn số sao để đánh giá lịch trình này:'), findsOneWidget);
      expect(find.text('4 sao'), findsOneWidget);

      // Verify all 3 action buttons exist
      expect(find.text('Xóa đánh giá'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Gửi'), findsOneWidget);

      // Verify no exceptions were thrown
      expect(tester.takeException(), isNull);
    });

        testWidgets('Dialog renders without overflow on ultra-narrow 320x480 screen with 5 stars selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSocial = MockSocialRepository();
      final detail = buildTestDetail(userRating: null, ratingCount: 0);
      final fakeNotifier = FakeItineraryDetailNotifier(
        itineraryId: detail.itineraryId,
        detail: detail,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: detail.itineraryId,
              initialDetail: detail,
              notifier: fakeNotifier,
              socialRepository: mockSocial,
              authNotifier: FakeTestAuthNotifier(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to rating section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
      await tester.pumpAndSettle();

      final rateBtnFinder = find.widgetWithText(OutlinedButton, 'Đánh giá');
      expect(rateBtnFinder, findsOneWidget);
      await tester.tap(rateBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Đánh giá lịch trình'), findsOneWidget);

      // Tap 5th star
      final star5Finder = find.byTooltip('5 sao');
      expect(star5Finder, findsOneWidget);
      await tester.tap(star5Finder);
      await tester.pumpAndSettle();
      expect(find.text('5 sao'), findsOneWidget);

      // Tap 2nd star
      final star2Finder = find.byTooltip('2 sao');
      expect(star2Finder, findsOneWidget);
      await tester.tap(star2Finder);
      await tester.pumpAndSettle();
      expect(find.text('2 sao'), findsOneWidget);

      // Submit
      await tester.tap(find.text('Gửi'));
      await tester.pumpAndSettle();

      expect(mockSocial.rateCalls, 1);
      expect(mockSocial.lastScore, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('2. Section Order - Comments Section precedes Rating Section', () {
    testWidgets('CommentsSection is rendered BEFORE RatingSection in the scroll tree', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final detail = buildTestDetail(
        ratingCount: 5,
        averageRating: 4.6,
        userRating: 5,
      );
      final fakeNotifier = FakeItineraryDetailNotifier(
        itineraryId: detail.itineraryId,
        detail: detail,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: detail.itineraryId,
              initialDetail: detail,
              notifier: fakeNotifier,
              authNotifier: FakeTestAuthNotifier(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll so both Comments and Rating sections enter viewport
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();

      final commentsFinder = find.byType(ItineraryCommentsSection);
      expect(commentsFinder, findsOneWidget);

      final ratingHeaderFinder = find.text('Đánh giá (5)');
      expect(ratingHeaderFinder, findsOneWidget);

      // Verify vertical positioning: comments section top coordinate < rating section top coordinate
      final commentsTop = tester.getTopLeft(commentsFinder).dy;
      final ratingTop = tester.getTopLeft(ratingHeaderFinder).dy;

      expect(
        commentsTop,
        lessThan(ratingTop),
        reason: 'Phần bình luận (Comments) phải nằm trên phần đánh giá (Ratings)',
      );
    });

    testWidgets('Empty state: when comments and ratings are empty, both render cleanly in order', (
      tester,
    ) async {
      final detail = buildTestDetail(
        ratingCount: 0,
        averageRating: 0.0,
        userRating: null,
      );
      final fakeNotifier = FakeItineraryDetailNotifier(
        itineraryId: detail.itineraryId,
        detail: detail,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: detail.itineraryId,
              initialDetail: detail,
              notifier: fakeNotifier,
              authNotifier: FakeTestAuthNotifier(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify comments empty section is rendered
      expect(find.byType(ItineraryCommentsSection), findsOneWidget);

      // Verify ratings empty section is rendered
      expect(find.text('Đánh giá (0)'), findsOneWidget);
      expect(find.text('0.0'), findsOneWidget);
      expect(find.text('Chưa có lượt đánh giá nào'), findsOneWidget);
      expect(find.text('Bạn đã trải nghiệm lịch trình này chưa?'), findsOneWidget);
    });

    testWidgets('Owner viewing itinerary: shows notice that owner cannot rate', (
      tester,
    ) async {
      // Viewer userId matches creator userId (10)
      final detail = buildTestDetail(
        creatorUserId: 10,
        ratingCount: 2,
        averageRating: 5.0,
      );
      final fakeNotifier = FakeItineraryDetailNotifier(
        itineraryId: detail.itineraryId,
        detail: detail,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: detail.itineraryId,
              initialDetail: detail,
              notifier: fakeNotifier,
              isOwner: true,
              authNotifier: FakeTestAuthNotifier(userId: 10, username: 'mock_author'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bạn là người tạo lịch trình này (không thể tự đánh giá)'),
        findsOneWidget,
      );
      // Owner should NOT see "Đánh giá ngay" action button
      expect(find.text('Đánh giá ngay'), findsNothing);
    });
  });
}



