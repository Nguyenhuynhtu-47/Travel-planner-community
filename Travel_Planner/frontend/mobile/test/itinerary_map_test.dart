import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/destination_summary.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_map_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/itinerary_map_helper.dart';
import 'package:mobile/features/itinerary/presentation/widgets/itinerary_map_preview_card.dart';
import 'package:mobile/shared/widgets/app_map_view.dart';

class _FakeItineraryDetailNotifier extends ItineraryDetailNotifier {
  final ItineraryDetail detail;

  _FakeItineraryDetailNotifier({
    required super.itineraryId,
    required this.detail,
  });

  @override
  Future<void> loadDetail({String? token}) async {
    itineraryDetail = detail;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  String? get token => 'token123';

  @override
  bool get isAuthenticated => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test data fixture
  final testItinerary = ItineraryDetail(
    itineraryId: 10,
    title: 'Hành Trình Khám Phá Đà Lạt 3N2Đ',
    description: 'Lịch trình tham quan các điểm nổi tiếng',
    location: 'Đà Lạt',
    totalDays: 3,
    budget: 3500000.0,
    viewCount: 100,
    favoriteCount: 25,
    ratingCount: 10,
    averageRating: 4.9,
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    creator: const CreatorSummary(
      userId: 1,
      username: 'dalat_traveler',
      fullName: 'Trần Du Lịch',
    ),
    days: [
      // Day 1: 3 activities (2 with coordinates, 1 without)
      ItineraryDayDetail(
        dayId: 101,
        dayNumber: 1,
        title: 'Ngày 1: Check-in & Cà phê',
        activities: [
          const ActivityDetail(
            activityId: 1001,
            name: 'Check-in Khách sạn Colline',
            customLocationName: 'Hôtel Colline',
            customAddress: '10 Phan Bội Châu, Đà Lạt',
            latitude: 11.9431,
            longitude: 108.4382,
            displayOrder: 1,
            startTime: '08:00',
            endTime: '09:00',
            estimatedCost: 1200000.0,
          ),
          const ActivityDetail(
            activityId: 1002,
            name: 'Nghỉ ngơi tại phòng',
            displayOrder: 2,
            startTime: '09:00',
            endTime: '10:00',
            // No coordinates (No Location state)
          ),
          ActivityDetail(
            activityId: 1003,
            name: 'Cà phê Tùng',
            displayOrder: 3,
            startTime: '10:30',
            endTime: '12:00',
            estimatedCost: 60000.0,
            locationName: 'Quán Cà Phê Tùng',
            locationAddress: '06 Khu Hòa Bình, Đà Lạt',
            latitude: 11.9404,
            longitude: 108.4385,
            destination: const DestinationSummary(
              destinationId: 501,
              name: 'Quán Cà Phê Tùng',
              address: '06 Khu Hòa Bình, Đà Lạt',
              latitude: 11.9404,
              longitude: 108.4385,
            ),
          ),
        ],
      ),
      // Day 2: 2 activities (both without coordinates)
      ItineraryDayDetail(
        dayId: 102,
        dayNumber: 2,
        title: 'Ngày 2: Khám phá ẩm thực tự do',
        activities: [
          const ActivityDetail(
            activityId: 2001,
            name: 'Ăn sáng bánh mì xíu mại',
            displayOrder: 1,
          ),
          const ActivityDetail(
            activityId: 2002,
            name: 'Dạo chợ đêm Đà Lạt',
            displayOrder: 2,
          ),
        ],
      ),
      // Day 3: Empty day (0 activities)
      ItineraryDayDetail(
        dayId: 103,
        dayNumber: 3,
        title: 'Ngày 3: Tạm biệt Đà Lạt',
        activities: [],
      ),
    ],
  );

  group('Phase 5 - ItineraryMapHelper Coordinate Validation Tests', () {
    test('isValidCoordinate accepts standard valid coordinates', () {
      expect(ItineraryMapHelper.isValidCoordinate(11.9431, 108.4382), isTrue);
      expect(ItineraryMapHelper.isValidCoordinate(0.0, 0.0), isTrue);
      expect(ItineraryMapHelper.isValidCoordinate(-90.0, -180.0), isTrue);
      expect(ItineraryMapHelper.isValidCoordinate(90.0, 180.0), isTrue);
    });

    test('isValidCoordinate rejects null or incomplete pairs', () {
      expect(ItineraryMapHelper.isValidCoordinate(null, 108.4382), isFalse);
      expect(ItineraryMapHelper.isValidCoordinate(11.9431, null), isFalse);
      expect(ItineraryMapHelper.isValidCoordinate(null, null), isFalse);
    });

    test('isValidCoordinate rejects out-of-range coordinates', () {
      expect(ItineraryMapHelper.isValidCoordinate(90.0001, 108.0), isFalse);
      expect(ItineraryMapHelper.isValidCoordinate(-90.0001, 108.0), isFalse);
      expect(ItineraryMapHelper.isValidCoordinate(11.0, 180.0001), isFalse);
      expect(ItineraryMapHelper.isValidCoordinate(11.0, -180.0001), isFalse);
    });

    test('isValidCoordinate rejects NaN and Infinite values', () {
      expect(
        ItineraryMapHelper.isValidCoordinate(double.nan, 108.0),
        isFalse,
      );
      expect(
        ItineraryMapHelper.isValidCoordinate(11.0, double.infinity),
        isFalse,
      );
      expect(
        ItineraryMapHelper.isValidCoordinate(double.negativeInfinity, 108.0),
        isFalse,
      );
    });
  });

  group('Phase 5 - Marker Generation & Sequence Logic Tests', () {
    test('extractMappedStops extracts only activities with valid coordinates', () {
      final day1Stops = ItineraryMapHelper.extractMappedStops(
        testItinerary,
        selectedDayNumber: 1,
      );

      // Day 1 has 3 activities total, but only 2 have valid coordinates
      expect(day1Stops.length, equals(2));
      expect(day1Stops[0].activity.name, equals('Check-in Khách sạn Colline'));
      expect(day1Stops[0].sequence, equals(1));
      expect(day1Stops[0].point.latitude, equals(11.9431));
      expect(day1Stops[0].point.longitude, equals(108.4382));

      expect(day1Stops[1].activity.name, equals('Cà phê Tùng'));
      expect(day1Stops[1].sequence, equals(3)); // 3rd activity in Day 1 list
      expect(day1Stops[1].point.latitude, equals(11.9404));
      expect(day1Stops[1].point.longitude, equals(108.4385));
    });

    test('extractMappedStops extracts stops across all days when dayNumber is null', () {
      final allStops = ItineraryMapHelper.extractMappedStops(
        testItinerary,
        selectedDayNumber: null,
      );

      // Across all 3 days, only Day 1 has located activities (2 total)
      expect(allStops.length, equals(2));
      expect(allStops[0].day.dayNumber, equals(1));
      expect(allStops[1].day.dayNumber, equals(1));
    });

    test('extractMappedStops returns empty list for day with no coordinates', () {
      final day2Stops = ItineraryMapHelper.extractMappedStops(
        testItinerary,
        selectedDayNumber: 2,
      );

      expect(day2Stops, isEmpty);
    });

    test('extractMappedStops returns empty list for empty day', () {
      final day3Stops = ItineraryMapHelper.extractMappedStops(
        testItinerary,
        selectedDayNumber: 3,
      );

      expect(day3Stops, isEmpty);
    });

    test('buildActivityMarkers generates MapMarkerBuilder stop markers with day badges', () {
      final day1Stops = ItineraryMapHelper.extractMappedStops(
        testItinerary,
        selectedDayNumber: 1,
      );

      final markers = ItineraryMapHelper.buildActivityMarkers(
        stops: day1Stops,
        isMultiDay: true,
      );

      expect(markers.length, equals(2));
      expect(markers[0].point.latitude, equals(11.9431));
      expect(markers[1].point.latitude, equals(11.9404));
    });

    test('buildActivityMarkers applies radial offset when multiple stops have identical coordinates', () {
      final stop1 = MappedActivityStop(
        activity: testItinerary.days[0].activities[0],
        day: testItinerary.days[0],
        sequence: 1,
        point: LatLng(16.0, 108.0),
      );
      final stop2 = MappedActivityStop(
        activity: testItinerary.days[1].activities[0],
        day: testItinerary.days[1],
        sequence: 1,
        point: LatLng(16.0, 108.0),
      );

      final markers = ItineraryMapHelper.buildActivityMarkers(
        stops: [stop1, stop2],
        isMultiDay: true,
      );

      expect(markers.length, equals(2));
      // Stop points should be offset and not identically equal to each other so earlier days are not hidden
      expect(markers[0].point, isNot(equals(markers[1].point)));
      // Both markers should remain in the immediate vicinity (~25 meters)
      expect((markers[0].point.latitude - 16.0).abs(), lessThan(0.0003));
      expect((markers[1].point.latitude - 16.0).abs(), lessThan(0.0003));
    });
  });

  group('Phase 5 - Missing-Coordinate Calculation Tests', () {
    test('Calculates missing coordinates count correctly for Day 1', () {
      final missing = ItineraryMapHelper.countMissingCoordinates(
        testItinerary,
        selectedDayNumber: 1,
      );
      // 3 activities, 2 have coordinates -> 1 missing
      expect(missing, equals(1));

      final notice = ItineraryMapHelper.getMissingCoordinatesMessage(
        testItinerary,
        selectedDayNumber: 1,
      );
      expect(notice, equals('1 hoạt động chưa có vị trí trên bản đồ'));
    });

    test('Reports all activities missing when none have coordinates in Day 2', () {
      final missing = ItineraryMapHelper.countMissingCoordinates(
        testItinerary,
        selectedDayNumber: 2,
      );
      // 2 activities, 0 have coordinates -> 2 missing
      expect(missing, equals(2));

      final notice = ItineraryMapHelper.getMissingCoordinatesMessage(
        testItinerary,
        selectedDayNumber: 2,
      );
      expect(notice, equals('Chưa có hoạt động nào có vị trí trên bản đồ'));
    });

    test('Returns null notice when day has zero activities in Day 3', () {
      final missing = ItineraryMapHelper.countMissingCoordinates(
        testItinerary,
        selectedDayNumber: 3,
      );
      expect(missing, equals(0));

      final notice = ItineraryMapHelper.getMissingCoordinatesMessage(
        testItinerary,
        selectedDayNumber: 3,
      );
      expect(notice, isNull);
    });
  });

  group('Phase 5 - ItineraryMapPreviewCard Widget Tests', () {
    testWidgets('Renders preview card with title, map, points count, and missing warning',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryMapPreviewCard(
              itinerary: testItinerary,
              selectedDayNumber: 1,
            ),
          ),
        ),
      );

      expect(find.text('Bản đồ Ngày 1'), findsOneWidget);
      expect(find.text('2 điểm'), findsOneWidget);
      expect(find.text('1 hoạt động chưa có vị trí trên bản đồ'), findsOneWidget);
      expect(find.byType(AppMapView), findsOneWidget);
    });

    testWidgets('Tapping Toàn màn hình button invokes onOpenFullScreen callback',
        (tester) async {
      var fullScreenOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryMapPreviewCard(
              itinerary: testItinerary,
              selectedDayNumber: 1,
              onOpenFullScreen: () => fullScreenOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('Toàn màn hình'), findsOneWidget);
      await tester.tap(find.text('Toàn màn hình'));
      await tester.pump();

      expect(fullScreenOpened, isTrue);
    });

    testWidgets('Renders empty day overlay when day has zero activities',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryMapPreviewCard(
              itinerary: testItinerary,
              selectedDayNumber: 3, // Day 3 is empty
            ),
          ),
        ),
      );

      expect(find.text('Bản đồ Ngày 3'), findsOneWidget);
      expect(find.text('Chưa có hoạt động nào trong ngày này'), findsOneWidget);
    });

    testWidgets('Renders no-coordinates overlay when activities exist but lack coordinates',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryMapPreviewCard(
              itinerary: testItinerary,
              selectedDayNumber: 2, // Day 2 has activities without coordinates
            ),
          ),
        ),
      );

      expect(
        find.text('Các hoạt động trong ngày này chưa có vị trí trên bản đồ'),
        findsOneWidget,
      );
    });

    testWidgets('Updating selectedDayNumber dynamically clears stale activity selection',
        (tester) async {
      final cardKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return ItineraryMapPreviewCard(
                  key: cardKey,
                  itinerary: testItinerary,
                  selectedDayNumber: 1,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Bản đồ Ngày 1'), findsOneWidget);

      // Rebuild with Day 2
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryMapPreviewCard(
              itinerary: testItinerary,
              selectedDayNumber: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bản đồ Ngày 2'), findsOneWidget);
    });
  });

  group('Phase 5 - ItineraryMapScreen Full-Screen Widget Tests', () {
    testWidgets('Renders full-screen map, app bar, day chips, and recenter action',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
          ),
        ),
      );

      // App bar elements
      expect(find.text('Hành Trình Khám Phá Đà Lạt 3N2Đ'), findsOneWidget);
      expect(find.text('Đà Lạt • Bản đồ lịch trình'), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong_outlined), findsOneWidget);

      // Day selector chips
      expect(find.text('Tất cả (3)'), findsOneWidget);
      expect(find.text('Ngày 1 (3)'), findsOneWidget);
      expect(find.text('Ngày 2 (2)'), findsOneWidget);
      expect(find.text('Ngày 3 (0)'), findsOneWidget);

      // Missing notice floating pill
      expect(find.text('1 hoạt động chưa có vị trí trên bản đồ'), findsOneWidget);

      // Map canvas
      expect(find.byType(AppMapView), findsOneWidget);
    });

    testWidgets('Switching day chips updates day selection and missing notice',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
          ),
        ),
      );

      expect(find.text('1 hoạt động chưa có vị trí trên bản đồ'), findsOneWidget);

      // Tap Ngày 2 chip
      await tester.ensureVisible(find.text('Ngày 2 (2)'));
      await tester.tap(find.text('Ngày 2 (2)'));
      await tester.pumpAndSettle();

      // Day 2 has no coordinates -> shows overlay
      expect(
        find.text('Các hoạt động trong ngày này chưa có vị trí trên bản đồ'),
        findsWidgets,
      );

      // Tap Ngày 3 chip (empty day)
      await tester.ensureVisible(find.text('Ngày 3 (0)'));
      await tester.tap(find.text('Ngày 3 (0)'));
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có hoạt động nào trong ngày này'),
        findsOneWidget,
      );
    });

    testWidgets('Single coordinate day centers camera on marker without bounds error',
        (tester) async {
      final singleLocationItinerary = ItineraryDetail(
        itineraryId: 99,
        title: 'Chuyến Đi 1 Điểm',
        location: 'Vũng Tàu',
        totalDays: 1,
        budget: 500000.0,
        viewCount: 1,
        favoriteCount: 0,
        ratingCount: 0,
        averageRating: 5.0,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        days: [
          ItineraryDayDetail(
            dayId: 991,
            dayNumber: 1,
            activities: [
              const ActivityDetail(
                activityId: 9901,
                name: 'Ngọn Hải Đăng',
                latitude: 10.3341,
                longitude: 107.0745,
                displayOrder: 1,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: singleLocationItinerary,
            initialDayNumber: 1,
          ),
        ),
      );

      // Renders cleanly without bounds error
      expect(find.byType(AppMapView), findsOneWidget);
      expect(find.text('Chuyến Đi 1 Điểm'), findsOneWidget);
    });

    testWidgets('Tapping marker in full-screen map shows bottom activity card with details',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
          ),
        ),
      );

      // Initially no bottom card is displayed
      expect(find.text('Điểm #1'), findsNothing);

      // Find the stop marker
      final markerFinder = find.text('3');
      expect(markerFinder, findsOneWidget);

      await tester.tap(markerFinder);
      await tester.pumpAndSettle();

      // Bottom floating card appears with details
      expect(find.text('Điểm #3'), findsOneWidget);
      expect(find.text('Ngày 1'), findsWidgets);
      expect(find.text('Cà phê Tùng'), findsOneWidget);
      expect(find.text('Quán Cà Phê Tùng'), findsOneWidget);
      expect(find.text('10:30 - 12:00'), findsOneWidget);
      expect(find.text('60.000 ₫'), findsOneWidget);

      // Tapping close icon dismisses the card
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Điểm #3'), findsNothing);
    });
  });

  group('Phase 5 - ItineraryDetailScreen Map Integration Tests', () {
    testWidgets('ItineraryDetailScreen embeds ItineraryMapPreviewCard with day markers',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async => http.Response('{}', 200));
      final repo = ItineraryCrudRepository(apiClient: ApiClient(client: mockClient));
      final auth = _FakeAuthNotifier();
      final notifier = _FakeItineraryDetailNotifier(
        itineraryId: 10,
        detail: testItinerary,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 10,
            notifier: notifier,
            authNotifier: auth,
            crudRepository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Preview card is embedded and visible
      expect(find.byType(ItineraryMapPreviewCard), findsOneWidget);
      expect(find.text('Bản đồ lịch trình'), findsOneWidget);
      expect(find.text('2 điểm'), findsOneWidget);
      expect(find.text('Toàn màn hình'), findsOneWidget);

      // Day selector chips are visible
      expect(find.text('Tất cả (3)'), findsOneWidget);
      expect(find.text('Ngày 1 (3)'), findsOneWidget);

      // Switching day chip to Ngày 2 updates preview card title to "Bản đồ Ngày 2"
      await tester.tap(find.text('Ngày 2 (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Bản đồ Ngày 2'), findsOneWidget);
    });
  });
}
