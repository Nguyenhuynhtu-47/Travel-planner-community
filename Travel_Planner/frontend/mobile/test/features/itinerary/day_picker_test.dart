import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/itinerary_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/create_activity_request.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_place.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_form_dialog.dart';
import 'package:mobile/features/itinerary/presentation/widgets/day_picker_bottom_sheet.dart';
import 'package:mobile/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart';
import 'package:mobile/features/location/data/location_repository.dart';
import 'package:mobile/features/location/data/models/location_search_result.dart';
import 'package:mobile/features/location/presentation/widgets/location_picker_sheet.dart';

class MockItineraryRepository extends ItineraryRepository {
  ItineraryDetail? detailToReturn;
  bool throwException;
  ApiException? exceptionToThrow;
  int getItineraryDetailCallCount = 0;
  int? lastRequestedId;

  MockItineraryRepository({
    this.detailToReturn,
    this.throwException = false,
    this.exceptionToThrow,
  });

  @override
  Future<ItineraryDetail> getItineraryDetail(
    int itineraryId, {
    String? token,
  }) async {
    getItineraryDetailCallCount++;
    lastRequestedId = itineraryId;

    if (throwException) {
      throw exceptionToThrow ??
          ApiException(statusCode: 500, message: 'Server error');
    }

    return detailToReturn ??
        ItineraryDetail(
          itineraryId: itineraryId,
          title: 'Mock Itinerary',
          location: 'Mock Location',
          totalDays: 0,
          budget: 1000000,
          viewCount: 1,
          favoriteCount: 1,
          ratingCount: 0,
          averageRating: 0.0,
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          days: const [],
        );
  }
}

class MockCrudRepository extends ItineraryCrudRepository {
  List<ItinerarySummary> itinerariesToReturn;
  CreateActivityRequest? lastCreateActivityRequest;
  int? lastAddActivityItineraryId;
  int? lastAddActivityDayId;

  MockCrudRepository({this.itinerariesToReturn = const []});

  @override
  Future<PageResult<ItinerarySummary>> getMyItineraries({
    String? token,
    int page = 0,
    int size = 10,
    String sort = 'createdAt,desc',
    String? status,
    String? visibility,
  }) async {
    return PageResult<ItinerarySummary>(
      content: itinerariesToReturn,
      pageNumber: page,
      pageSize: size,
      totalElements: itinerariesToReturn.length,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<ActivityDetail> addActivity(
    int itineraryId,
    int dayId,
    CreateActivityRequest request, {
    String? token,
  }) async {
    lastAddActivityItineraryId = itineraryId;
    lastAddActivityDayId = dayId;
    lastCreateActivityRequest = request;
    return ActivityDetail(
      activityId: 999,
      name: request.name,
      locationName: request.locationName,
      displayOrder: 1,
    );
  }

  @override
  Future<List<ItineraryPlace>> getSavedPlaces(
    int itineraryId, {
    String? token,
  }) async {
    return const [];
  }
}

class MockAuthNotifier extends AuthNotifier {
  @override
  String? get token => 'test-token-123';

  @override
  bool get isAuthenticated => true;
}

class MockLocationRepo extends LocationRepository {
  List<LocationSearchResult> searchResultsToReturn;
  MockLocationRepo({this.searchResultsToReturn = const []});

  @override
  Future<List<LocationSearchResult>> searchLocations(
    String query, {
    int? limit,
    String? token,
    String mode = 'SUGGEST',
    String? sessionId,
  }) async {
    return searchResultsToReturn;
  }
}

void main() {
  const samplePlace = LocationSearchResult(
    placeId: 'place_10',
    name: 'Bảo tàng Chứng tích Chiến tranh',
    formattedAddress: '28 Võ Văn Tần, Quận 3',
    provider: 'SYSTEM',
    type: 'place',
    latitude: 10.7794,
    longitude: 106.6923,
  );

  final sampleDays = [
    ItineraryDayDetail(
      dayId: 201,
      dayNumber: 1,
      title: 'Khởi hành & Nhận phòng',
      date: DateTime(2026, 12, 1),
      activities: [
        const ActivityDetail(
          activityId: 1,
          name: 'Ăn sáng phở Thìn',
          locationName: 'Phở Thìn',
          displayOrder: 1,
        ),
      ],
    ),
    ItineraryDayDetail(
      dayId: 202,
      dayNumber: 2,
      title: 'Tham quan bảo tàng & Cà phê',
      date: DateTime(2026, 12, 2),
      activities: const [],
    ),
  ];

  final sampleDetail = ItineraryDetail(
    itineraryId: 101,
    title: 'Chuyến đi Sài Gòn 2N1Đ',
    location: 'TP. Hồ Chí Minh',
    totalDays: 2,
    budget: 2000000,
    viewCount: 10,
    favoriteCount: 2,
    ratingCount: 1,
    averageRating: 5.0,
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    days: sampleDays,
  );

  const sampleSummary = ItinerarySummary(
    itineraryId: 101,
    title: 'Chuyến đi Sài Gòn 2N1Đ',
    location: 'TP. Hồ Chí Minh',
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    totalDays: 2,
    budget: 2000000,
    viewCount: 10,
    favoriteCount: 2,
    ratingCount: 1,
    averageRating: 5.0,
  );

  const zeroDaysSummary = ItinerarySummary(
    itineraryId: 102,
    title: 'Lịch trình dự thảo chưa có ngày',
    location: 'Đà Nẵng',
    visibility: 'PRIVATE',
    status: 'ACTIVE',
    totalDays: 0,
    budget: 500000,
    viewCount: 0,
    favoriteCount: 0,
    ratingCount: 0,
    averageRating: 0.0,
  );

  group('Phase 6A.2 - DayPickerBottomSheet Widget Tests', () {
    testWidgets('renders days list with day titles and activity counts successfully', (tester) async {
      final mockRepo = MockItineraryRepository(detailToReturn: sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPickerBottomSheet(
              itinerary: sampleSummary,
              place: samplePlace,
              token: 'test-token',
              itineraryRepository: mockRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(mockRepo.getItineraryDetailCallCount, 1);
      expect(mockRepo.lastRequestedId, 101);
      expect(find.text('Chọn ngày lên lịch'), findsOneWidget);
      expect(find.text('Chuyến đi Sài Gòn 2N1Đ • Bảo tàng Chứng tích Chiến tranh'), findsOneWidget);
      expect(find.text('Ngày 1: Khởi hành & Nhận phòng'), findsOneWidget);
      expect(find.text('Ngày 2: Tham quan bảo tàng & Cà phê'), findsOneWidget);
      expect(find.text('1 hoạt động'), findsOneWidget);
      expect(find.text('0 hoạt động'), findsOneWidget);
      expect(find.text('Chọn'), findsNWidgets(2));
    });

    testWidgets('displays empty state when itinerary has 0 days', (tester) async {
      final mockRepo = MockItineraryRepository(
        detailToReturn: ItineraryDetail(
          itineraryId: 102,
          title: 'Lịch trình dự thảo chưa có ngày',
          location: 'Đà Nẵng',
          totalDays: 0,
          budget: 0,
          viewCount: 0,
          favoriteCount: 0,
          ratingCount: 0,
          averageRating: 0.0,
          visibility: 'PRIVATE',
          status: 'ACTIVE',
          days: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPickerBottomSheet(
              itinerary: zeroDaysSummary,
              place: samplePlace,
              token: 'test-token',
              itineraryRepository: mockRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lịch trình chưa có ngày nào'), findsOneWidget);
      expect(
        find.text('Lịch trình này chưa có ngày nào. Vui lòng mở chi tiết lịch trình để thêm ngày trước.'),
        findsOneWidget,
      );
      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets('displays error state and allows retry on network failure', (tester) async {
      final mockRepo = MockItineraryRepository(
        throwException: true,
        exceptionToThrow: ApiException(
          statusCode: 500,
          message: 'Lỗi tải chi tiết lịch trình',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPickerBottomSheet(
              itinerary: sampleSummary,
              place: samplePlace,
              token: 'test-token',
              itineraryRepository: mockRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lỗi tải chi tiết lịch trình'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Fix repo and retry
      mockRepo.throwException = false;
      mockRepo.detailToReturn = sampleDetail;

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(mockRepo.getItineraryDetailCallCount, 2);
      expect(find.text('Ngày 1: Khởi hành & Nhận phòng'), findsOneWidget);
    });

    testWidgets('selecting a day pops sheet and returns chosen ItineraryDayDetail', (tester) async {
      final mockRepo = MockItineraryRepository(detailToReturn: sampleDetail);
      ItineraryDayDetail? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await DayPickerBottomSheet.show(
                    context,
                    itinerary: sampleSummary,
                    place: samplePlace,
                    token: 'test-token',
                    itineraryRepository: mockRepo,
                  );
                },
                child: const Text('Open Day Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Day Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Chọn ngày lên lịch'), findsOneWidget);

      // Select Day 1
      await tester.tap(find.widgetWithText(FilledButton, 'Chọn').first);
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!.dayId, 201);
      expect(selectedResult!.dayNumber, 1);
      expect(find.text('Chọn ngày lên lịch'), findsNothing);
    });
  });

  group('Phase 6A.2 - ItineraryPickerBottomSheet Schedule Mode Tests', () {
    testWidgets('renders schedule title and allows selecting itinerary', (tester) async {
      final mockCrud = MockCrudRepository(
        itinerariesToReturn: [sampleSummary, zeroDaysSummary],
      );
      ItinerarySummary? chosenItinerary;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  chosenItinerary = await ItineraryPickerBottomSheet.showForSchedule(
                    context,
                    place: samplePlace,
                    token: 'test-token',
                    repository: mockCrud,
                  );
                },
                child: const Text('Open Schedule Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Schedule Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Lên lịch vào chuyến đi'), findsOneWidget);
      expect(find.text('Chọn'), findsNWidgets(2));

      // Tap itinerary with 0 days: should show SnackBar and NOT dismiss sheet
      await tester.tap(find.byKey(const Key('select_itinerary_102')));
      await tester.pumpAndSettle();

      expect(
        find.text('Lịch trình này chưa có ngày nào. Vui lòng mở chi tiết lịch trình để thêm ngày trước.'),
        findsOneWidget,
      );
      expect(find.text('Lên lịch vào chuyến đi'), findsOneWidget);
      expect(chosenItinerary, isNull);

      // Now tap valid itinerary with days: should select and dismiss
      await tester.tap(find.byKey(const Key('select_itinerary_101')));
      await tester.pumpAndSettle();

      expect(chosenItinerary, isNotNull);
      expect(chosenItinerary!.itineraryId, 101);
      expect(find.text('Lên lịch vào chuyến đi'), findsNothing);
    });
  });

  group('Phase 6A.2 - LocationPickerSheet Schedule as Activity Integration', () {
    testWidgets('renders active Schedule Activity button for Internal Place', (tester) async {
      final fakeLocationRepo = MockLocationRepo(
        searchResultsToReturn: [samplePlace],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              repository: fakeLocationRepo,
              token: 'test-token',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Chứng tích');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Bảo tàng Chứng tích Chiến tranh'));
      await tester.pumpAndSettle();

      // Both Save to Itinerary and Schedule Activity buttons must be present
      expect(find.byKey(const Key('save_to_itinerary_button')), findsOneWidget);
      expect(find.byKey(const Key('schedule_activity_button')), findsOneWidget);
      expect(find.text('Lên lịch vào ngày'), findsOneWidget);
    });

    testWidgets('renders active Schedule Activity button for External POI', (tester) async {
      const externalPoi = LocationSearchResult(
        placeId: 'tomtom_123',
        name: 'Nhà hàng Ngon',
        formattedAddress: '160 Pasteur, Bến Nghé, Quận 1',
        provider: 'TOMTOM',
        type: 'poi',
        latitude: 10.7812,
        longitude: 106.6980,
      );

      final fakeLocationRepo = MockLocationRepo(
        searchResultsToReturn: [externalPoi],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              repository: fakeLocationRepo,
              token: 'test-token',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Nhà hàng');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Nhà hàng Ngon'));
      await tester.pumpAndSettle();

      // Schedule Activity is active; Save to Itinerary is disabled notice
      expect(find.byKey(const Key('schedule_activity_button')), findsOneWidget);
      expect(find.byKey(const Key('save_to_itinerary_button')), findsNothing);
      expect(
        find.text('Địa điểm này chưa có trong danh mục địa điểm của Travel Planner. Bạn vẫn có thể lên lịch trực tiếp vào một ngày trong chuyến đi.'),
        findsOneWidget,
      );
    });

    testWidgets('does NOT render Schedule Activity button for Administrative Boundary', (tester) async {
      const adminArea = LocationSearchResult(
        placeId: 'admin_79',
        name: 'Quận 1',
        formattedAddress: 'TP. Hồ Chí Minh',
        provider: 'SYSTEM',
        type: 'administrative',
        category: 'boundary',
        isLocalityFallback: true,
        latitude: 10.7769,
        longitude: 106.7009,
      );

      final fakeLocationRepo = MockLocationRepo(
        searchResultsToReturn: [adminArea],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              repository: fakeLocationRepo,
              token: 'test-token',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Quận 1');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Quận 1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schedule_activity_button')), findsNothing);
      expect(find.byKey(const Key('save_to_itinerary_button')), findsNothing);
      expect(
        find.text('Đây là ranh giới khu vực hành chính, không thể lưu vào lịch trình.'),
        findsOneWidget,
      );
    });
  });

  group('Phase 6A.2 - ActivityFormBottomSheet Location Prefill Tests', () {
    testWidgets('prefills name and sets canonicalPlaceId with null coordinates for Internal Place', (tester) async {
      final mockCrud = MockCrudRepository();
      final fakeAuth = MockAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityFormBottomSheet(
              itineraryId: 101,
              dayId: 201,
              dayNumber: 1,
              authNotifier: fakeAuth,
              repository: mockCrud,
              initialLocation: samplePlace,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check pre-populated name
      expect(find.text('Bảo tàng Chứng tích Chiến tranh'), findsWidgets);

      // Submit form
      final submitButton = find.widgetWithText(ElevatedButton, 'Thêm hoạt động');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify request payload
      expect(mockCrud.lastAddActivityItineraryId, 101);
      expect(mockCrud.lastAddActivityDayId, 201);
      expect(mockCrud.lastCreateActivityRequest, isNotNull);
      final req = mockCrud.lastCreateActivityRequest!;
      expect(req.name, 'Bảo tàng Chứng tích Chiến tranh');
      expect(req.canonicalPlaceId, 10);
      expect(req.latitude, isNull);
      expect(req.longitude, isNull);
      expect(req.locationProvider, 'PLACE_CATALOG');
      expect(req.locationName, 'Bảo tàng Chứng tích Chiến tranh');
    });

    testWidgets('prefills name and sets coordinates with null canonicalPlaceId for External POI', (tester) async {
      const externalPoi = LocationSearchResult(
        placeId: 'tomtom_123',
        name: 'Nhà hàng Ngon',
        formattedAddress: '160 Pasteur, Bến Nghé, Quận 1',
        provider: 'TOMTOM',
        type: 'poi',
        latitude: 10.7812,
        longitude: 106.6980,
      );

      final mockCrud = MockCrudRepository();
      final fakeAuth = MockAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityFormBottomSheet(
              itineraryId: 101,
              dayId: 201,
              dayNumber: 1,
              authNotifier: fakeAuth,
              repository: mockCrud,
              initialLocation: externalPoi,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check pre-populated name
      expect(find.text('Nhà hàng Ngon'), findsWidgets);

      // Submit form
      final submitButton = find.widgetWithText(ElevatedButton, 'Thêm hoạt động');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify request payload
      expect(mockCrud.lastAddActivityItineraryId, 101);
      expect(mockCrud.lastAddActivityDayId, 201);
      expect(mockCrud.lastCreateActivityRequest, isNotNull);
      final req = mockCrud.lastCreateActivityRequest!;
      expect(req.name, 'Nhà hàng Ngon');
      expect(req.canonicalPlaceId, isNull);
      expect(req.latitude, 10.7812);
      expect(req.longitude, 106.6980);
      expect(req.locationProvider, 'TOMTOM');
      expect(req.placeId, 'tomtom_123');
      expect(req.locationName, 'Nhà hàng Ngon');
    });
  });
}
