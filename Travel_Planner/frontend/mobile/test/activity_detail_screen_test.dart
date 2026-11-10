import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/comments/presentation/widgets/itinerary_comments_section.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/activity_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_timeline_item.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final Map<String, dynamic>? user;
  final String? fakeToken;

  _FakeAuthNotifier({this.user, String? token}) : fakeToken = token;

  @override
  Map<String, dynamic>? get currentUser => user;

  @override
  String? get token => fakeToken;

  @override
  bool get isAuthenticated => fakeToken != null;
}

class _FakeItineraryDetailNotifier extends ItineraryDetailNotifier {
  final ItineraryDetail _preset;

  _FakeItineraryDetailNotifier(this._preset)
      : super(
          itineraryId: _preset.itineraryId,
          initialDetail: _preset,
        );

  @override
  Future<void> loadDetail({String? token}) async {
    itineraryDetail = _preset;
    isLoading = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivityDetailScreen - Static Helpers', () {
    test('calculateDuration handles various time formats', () {
      expect(
        ActivityDetailScreen.calculateDuration('08:00', '10:30'),
        '2 giờ 30 phút',
      );
      expect(
        ActivityDetailScreen.calculateDuration('09:00', '10:00'),
        '1 giờ',
      );
      expect(
        ActivityDetailScreen.calculateDuration('14:15', '14:45'),
        '30 phút',
      );
      expect(
        ActivityDetailScreen.calculateDuration('23:00', '01:00'),
        '2 giờ',
      );
      expect(
        ActivityDetailScreen.calculateDuration('08:00:00', '09:30:00'),
        '1 giờ 30 phút',
      );
      expect(ActivityDetailScreen.calculateDuration(null, '10:00'), isNull);
      expect(ActivityDetailScreen.calculateDuration('10:00', null), isNull);
      expect(ActivityDetailScreen.calculateDuration('10:00', '10:00'), isNull);
      expect(ActivityDetailScreen.calculateDuration('invalid', '10:00'), isNull);
    });

    test('formatCost handles zero, negative, and positive amounts', () {
      expect(ActivityDetailScreen.formatCost(0), 'Miễn phí');
      expect(ActivityDetailScreen.formatCost(-50), 'Miễn phí');
      expect(ActivityDetailScreen.formatCost(150000), '150.000 ₫');
      expect(ActivityDetailScreen.formatCost(1500000), '1.500.000 ₫');
    });
  });

  group('ActivityDetailScreen - UI Rendering & Cases', () {
    testWidgets('Case 1: Renders activity with full information', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const activity = ActivityDetail(
        activityId: 101,
        name: 'Thăm Dinh Độc Lập',
        description: 'Tham quan di tích lịch sử nổi tiếng tại trung tâm TP.HCM.',
        activityType: 'VISIT',
        startTime: '08:00',
        endTime: '10:30',
        estimatedCost: 65000,
        displayOrder: 1,
        customLocationName: 'Dinh Độc Lập',
        customAddress: '135 Nam Kỳ Khởi Nghĩa, Bến Thành, Quận 1, TP.HCM',
        latitude: 10.7769,
        longitude: 106.6953,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ActivityDetailScreen(
            activity: activity,
            dayNumber: 1,
            dayTitle: 'Khám phá Quận 1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết hoạt động'), findsOneWidget);
      expect(find.text('Thăm Dinh Độc Lập'), findsOneWidget);
      expect(find.text('Ngày 1: Khám phá Quận 1'), findsOneWidget);
      expect(find.text('Thứ tự #1'), findsOneWidget);
      expect(find.text('VISIT'), findsOneWidget);
      expect(find.text('08:00 - 10:30'), findsOneWidget);
      expect(find.text('Thời lượng ước tính: 2 giờ 30 phút'), findsOneWidget);
      expect(find.text('65.000 ₫'), findsOneWidget);
      expect(find.text('Tham quan di tích lịch sử nổi tiếng tại trung tâm TP.HCM.'), findsOneWidget);
      expect(find.text('Dinh Độc Lập'), findsOneWidget);
      expect(find.text('135 Nam Kỳ Khởi Nghĩa, Bến Thành, Quận 1, TP.HCM'), findsOneWidget);
      expect(find.text('10.77690, 106.69530'), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);
      expect(find.text('Vị trí trên bản đồ'), findsOneWidget);
      expect(find.text('Chế độ xem chi tiết (chỉ đọc)'), findsOneWidget);
    });

    testWidgets('Case 2: Renders activity without image cleanly', (tester) async {
      const activity = ActivityDetail(
        activityId: 102,
        name: 'Ăn trưa cơm tấm',
        startTime: '12:00',
        endTime: '13:00',
        estimatedCost: 50000,
        displayOrder: 2,
        customLocationName: 'Quán Cơm Tấm Ba Ghiền',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ActivityDetailScreen(
            activity: activity,
            dayNumber: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ăn trưa cơm tấm'), findsOneWidget);
      expect(find.text('Ngày 2'), findsOneWidget);
      expect(find.text('50.000 ₫'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Quán Cơm Tấm Ba Ghiền'), findsOneWidget);
    });

    testWidgets('Case 3: Renders activity without location or coordinates', (tester) async {
      const activity = ActivityDetail(
        activityId: 103,
        name: 'Nghỉ ngơi tự do tại khách sạn',
        description: 'Thư giãn sau chuyến bay dài.',
        displayOrder: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ActivityDetailScreen(
            activity: activity,
            dayNumber: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nghỉ ngơi tự do tại khách sạn'), findsOneWidget);
      expect(
        find.text('Hoạt động này chưa có thông tin địa điểm cụ thể.'),
        findsOneWidget,
      );
      expect(find.text('Vị trí trên bản đồ'), findsNothing);
      expect(find.text('Chỉ đường'), findsNothing);
    });

    testWidgets('Case 4: Renders activity with long description without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final longDescription = 'Đây là đoạn mô tả rất dài về hoạt động trải nghiệm. ' * 20;

      final activity = ActivityDetail(
        activityId: 104,
        name: 'Hội thảo trải nghiệm văn hóa truyền thống',
        description: longDescription,
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ActivityDetailScreen(
            activity: activity,
            dayNumber: 3,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hội thảo trải nghiệm văn hóa truyền thống'), findsOneWidget);
      expect(find.text(longDescription.trim()), findsOneWidget);
    });

    testWidgets('Case 5 & 6: Back button returns to caller without modifying data', (tester) async {
      const activity = ActivityDetail(
        activityId: 105,
        name: 'Chợ Bến Thành',
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ActivityDetailScreen(
                          activity: activity,
                          dayNumber: 1,
                        ),
                      ),
                    );
                  },
                  child: const Text('Mở chi tiết'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở chi tiết'));
      await tester.pumpAndSettle();

      expect(find.text('Chợ Bến Thành'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Verified back at origin screen
      expect(find.text('Mở chi tiết'), findsOneWidget);
      expect(find.text('Chợ Bến Thành'), findsNothing);
    });

    testWidgets('Renders empty state when activity is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ActivityDetailScreen(activity: null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy hoạt động'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
    });
  });

  group('ActivityTimelineItem - Tap Interactions & Popup Menu', () {
    testWidgets('Tapping activity information area invokes onTap callback', (tester) async {
      bool tapped = false;

      const activity = ActivityDetail(
        activityId: 201,
        name: 'Bảo tàng Chứng tích Chiến tranh',
        description: 'Bảo tàng lịch sử nổi tiếng',
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ActivityTimelineItem(
              activity: activity,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on activity name
      await tester.tap(find.text('Bảo tàng Chứng tích Chiến tranh'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('Selecting "Xem chi tiết" from popup menu invokes onTap without edit/delete conflict', (tester) async {
      bool tapped = false;
      bool edited = false;
      bool deleted = false;

      const activity = ActivityDetail(
        activityId: 202,
        name: 'Nhà thờ Đức Bà',
        startTime: '09:00',
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ActivityTimelineItem(
              activity: activity,
              onTap: () => tapped = true,
              onEdit: () => edited = true,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open 3-dot popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Xem chi tiết'), findsOneWidget);
      expect(find.text('Sửa hoạt động'), findsOneWidget);
      expect(find.text('Xóa hoạt động'), findsOneWidget);

      // Tap 'Xem chi tiết'
      await tester.tap(find.text('Xem chi tiết'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(edited, isFalse);
      expect(deleted, isFalse);
    });
  });

  group('Requirement 1: Comments Visibility in Personal Itinerary Edit vs Public View', () {
    final testActivity = const ActivityDetail(
      activityId: 301,
      name: 'Đi bộ phố đi bộ Nguyễn Huệ',
      startTime: '19:00',
      endTime: '21:00',
      displayOrder: 1,
    );

    final testDay = ItineraryDayDetail(
      dayId: 501,
      dayNumber: 1,
      title: 'Buổi tối Sài Gòn',
      activities: [testActivity],
    );

    final publicActiveItinerary = ItineraryDetail(
      itineraryId: 999,
      title: 'Lịch trình TP.HCM 1 Ngày',
      description: 'Lịch trình mẫu',
      location: 'TP.HCM',
      budget: 500000,
      totalDays: 1,
      viewCount: 10,
      favoriteCount: 5,
      ratingCount: 3,
      averageRating: 4.5,
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      days: [testDay],
    );

    testWidgets('Owner editing personal itinerary: activity comment button and bottom comment section are completely hidden', (tester) async {
      final notifier = _FakeItineraryDetailNotifier(publicActiveItinerary);
      final authNotifier = _FakeAuthNotifier(user: {'username': 'test_author', 'userId': 1});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: 999,
              initialDetail: publicActiveItinerary,
              isOwner: true,
              notifier: notifier,
              authNotifier: authNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inside activity: "Bình luận hoạt động" must NOT be visible
      expect(find.text('Bình luận hoạt động'), findsNothing);

      // Bottom comments section must NOT be rendered
      expect(find.byType(ItineraryCommentsSection), findsNothing);

      // Activity should still be tappable to view detail
      expect(find.text('Đi bộ phố đi bộ Nguyễn Huệ'), findsOneWidget);
    });

    testWidgets('Non-owner viewing public itinerary: activity comments and itinerary comments section remain visible', (tester) async {
      final notifier = _FakeItineraryDetailNotifier(publicActiveItinerary);
      final authNotifier = _FakeAuthNotifier(user: {'username': 'guest_user', 'userId': 2});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: 999,
              initialDetail: publicActiveItinerary,
              isOwner: false,
              notifier: notifier,
              authNotifier: authNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inside activity: "Bình luận hoạt động" IS visible for public viewers
      expect(find.text('Bình luận hoạt động'), findsOneWidget);

      // Scroll down to check itinerary comments section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byType(ItineraryCommentsSection), findsOneWidget);
    });

    testWidgets('Tapping activity in personal itinerary navigates to ActivityDetailScreen', (tester) async {
      final notifier = _FakeItineraryDetailNotifier(publicActiveItinerary);
      final authNotifier = _FakeAuthNotifier(user: {'username': 'test_author', 'userId': 1});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ItineraryDetailScreen(
              itineraryId: 999,
              initialDetail: publicActiveItinerary,
              isOwner: true,
              notifier: notifier,
              authNotifier: authNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the activity in personal itinerary
      await tester.tap(find.text('Đi bộ phố đi bộ Nguyễn Huệ'));
      await tester.pumpAndSettle();

      // Should open ActivityDetailScreen
      expect(find.byType(ActivityDetailScreen), findsOneWidget);
      expect(find.text('Chi tiết hoạt động'), findsOneWidget);
      expect(find.text('Thời lượng ước tính: 2 giờ'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      // Returned to ItineraryDetailScreen
      expect(find.byType(ActivityDetailScreen), findsNothing);
      expect(find.text('Đi bộ phố đi bộ Nguyễn Huệ'), findsOneWidget);
    });
  });
}
