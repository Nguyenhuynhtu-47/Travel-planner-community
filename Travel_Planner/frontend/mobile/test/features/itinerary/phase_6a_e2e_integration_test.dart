import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/itinerary/data/helpers/location_activity_mapper.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/itinerary_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/create_activity_request.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_place.dart';
import 'package:mobile/features/itinerary/data/models/place_summary.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_form_dialog.dart';
import 'package:mobile/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart';
import 'package:mobile/features/location/data/location_repository.dart';
import 'package:mobile/features/location/data/models/location_search_result.dart';
import 'package:mobile/features/location/presentation/widgets/location_picker_sheet.dart';

class E2EAuthNotifier extends AuthNotifier {
  final String _testToken;
  E2EAuthNotifier({String token = 'test-e2e-token'}) : _testToken = token;

  @override
  String? get token => _testToken;

  @override
  bool get isAuthenticated => true;
}

class E2ECrudRepository extends ItineraryCrudRepository {
  List<ItinerarySummary> itineraries;
  bool throwOnGetMyItineraries;
  ApiException? getMyItinerariesException;

  final List<Map<String, dynamic>> savedPlaceCalls = [];
  bool throwOnSavePlace;
  ApiException? savePlaceException;

  final List<Map<String, dynamic>> addActivityCalls = [];
  bool throwOnAddActivity;
  ApiException? addActivityException;

  E2ECrudRepository({
    this.itineraries = const [],
    this.throwOnGetMyItineraries = false,
    this.getMyItinerariesException,
    this.throwOnSavePlace = false,
    this.savePlaceException,
    this.throwOnAddActivity = false,
    this.addActivityException,
  });

  @override
  Future<PageResult<ItinerarySummary>> getMyItineraries({
    String? token,
    int page = 0,
    int size = 10,
    String sort = 'createdAt,desc',
    String? status,
    String? visibility,
  }) async {
    if (throwOnGetMyItineraries) {
      throw getMyItinerariesException ??
          ApiException(statusCode: 500, message: 'Server error loading itineraries');
    }
    return PageResult<ItinerarySummary>(
      content: itineraries,
      pageNumber: page,
      pageSize: size,
      totalElements: itineraries.length,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<ItineraryPlace> savePlaceToItinerary(
    int itineraryId,
    int placeId, {
    required String token,
  }) async {
    savedPlaceCalls.add({
      'itineraryId': itineraryId,
      'placeId': placeId,
      'token': token,
    });
    if (throwOnSavePlace) {
      throw savePlaceException ??
          ApiException(statusCode: 500, message: 'Save place error');
    }
    return ItineraryPlace(
      id: 999,
      itineraryId: itineraryId,
      place: PlaceSummary(
        placeId: placeId,
        name: 'Mock Place',
        address: 'Mock Address',
        latitude: 10.7725,
        longitude: 106.6980,
      ),
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<ActivityDetail> addActivity(
    int itineraryId,
    int dayId,
    CreateActivityRequest request, {
    String? token,
  }) async {
    addActivityCalls.add({
      'itineraryId': itineraryId,
      'dayId': dayId,
      'request': request,
      'token': token,
    });
    if (throwOnAddActivity) {
      throw addActivityException ??
          ApiException(statusCode: 500, message: 'Add activity error');
    }
    return ActivityDetail(
      activityId: 888,
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

class E2EItineraryRepository extends ItineraryRepository {
  Map<int, ItineraryDetail> detailsMap = {};
  bool throwOnDetail;
  ApiException? detailException;

  E2EItineraryRepository({
    this.throwOnDetail = false,
    this.detailException,
  });

  @override
  Future<ItineraryDetail> getItineraryDetail(
    int itineraryId, {
    String? token,
  }) async {
    if (throwOnDetail) {
      throw detailException ??
          ApiException(statusCode: 500, message: 'Error loading itinerary detail');
    }
    if (detailsMap.containsKey(itineraryId)) {
      return detailsMap[itineraryId]!;
    }
    return ItineraryDetail(
      itineraryId: itineraryId,
      title: 'Itinerary $itineraryId',
      location: 'Default Location',
      totalDays: 0,
      budget: 0,
      viewCount: 0,
      favoriteCount: 0,
      ratingCount: 0,
      averageRating: 0.0,
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      days: const [],
    );
  }
}

class E2ELocationRepository extends LocationRepository {
  List<LocationSearchResult> searchResults;
  LocationSearchResult? reverseGeocodeResult;

  E2ELocationRepository({
    this.searchResults = const [],
    this.reverseGeocodeResult,
  });

  @override
  Future<List<LocationSearchResult>> searchLocations(
    String query, {
    int? limit,
    String? token,
    String mode = 'SUGGEST',
    String? sessionId,
  }) async {
    return searchResults;
  }

  @override
  Future<LocationSearchResult?> reverseGeocode(
    double latitude,
    double longitude, {
    String? token,
  }) async {
    return reverseGeocodeResult;
  }
}

void main() {
  const sampleInternalPlace = LocationSearchResult(
    placeId: 'place_10',
    name: 'Bảo tàng Chứng tích Chiến tranh',
    formattedAddress: '28 Võ Văn Tần, Quận 3, TP. Hồ Chí Minh',
    provider: 'SYSTEM',
    type: 'place',
    latitude: 10.7794,
    longitude: 106.6923,
  );

  const sampleExternalPoi = LocationSearchResult(
    placeId: 'tomtom_999',
    name: 'Nhà hàng Cơm Niêu Sài Gòn',
    formattedAddress: '59 Hồ Xuân Hương, Phường 6, Quận 3',
    provider: 'TOMTOM',
    type: 'poi',
    latitude: 10.7780,
    longitude: 106.6890,
  );

  const sampleAdminBoundary = LocationSearchResult(
    placeId: 'admin_79',
    name: 'Quận 3',
    formattedAddress: 'TP. Hồ Chí Minh, Việt Nam',
    provider: 'SYSTEM',
    type: 'administrative',
    category: 'boundary',
    isLocalityFallback: true,
    latitude: 10.7820,
    longitude: 106.6850,
  );

  final sampleDay1 = ItineraryDayDetail(
    dayId: 201,
    dayNumber: 1,
    title: 'Khám phá văn hóa & lịch sử',
    date: DateTime(2026, 12, 1),
    activities: const [],
  );

  final sampleDay2 = ItineraryDayDetail(
    dayId: 202,
    dayNumber: 2,
    title: 'Ẩm thực & Mua sắm',
    date: DateTime(2026, 12, 2),
    activities: const [],
  );

  final sampleDetail = ItineraryDetail(
    itineraryId: 101,
    title: 'Hành trình Sài Gòn 2 ngày',
    location: 'TP. Hồ Chí Minh',
    totalDays: 2,
    budget: 3000000,
    viewCount: 15,
    favoriteCount: 5,
    ratingCount: 3,
    averageRating: 4.8,
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    days: [sampleDay1, sampleDay2],
  );

  const sampleSummary = ItinerarySummary(
    itineraryId: 101,
    title: 'Hành trình Sài Gòn 2 ngày',
    location: 'TP. Hồ Chí Minh',
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    totalDays: 2,
    budget: 3000000,
    viewCount: 15,
    favoriteCount: 5,
    ratingCount: 3,
    averageRating: 4.8,
  );

  const zeroDaysSummary = ItinerarySummary(
    itineraryId: 102,
    title: 'Kế hoạch Đà Lạt chưa có ngày',
    location: 'Lâm Đồng',
    visibility: 'PRIVATE',
    status: 'ACTIVE',
    totalDays: 0,
    budget: 0,
    viewCount: 0,
    favoriteCount: 0,
    ratingCount: 0,
    averageRating: 0.0,
  );

  group('Phase 6A.3 - E2E Integration: Flow A (Save Place to Itinerary)', () {
    testWidgets('successfully saves internal place to itinerary and handles UI feedback', (tester) async {
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final auth = E2EAuthNotifier();

      bool? saveCallbackTriggered;
      int? savedItineraryId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await ItineraryPickerBottomSheet.show(
                    context,
                    place: sampleInternalPlace,
                    token: auth.token!,
                    repository: crudRepo,
                    authNotifier: auth,
                    onSaved: (id) {
                      saveCallbackTriggered = true;
                      savedItineraryId = id;
                    },
                  );
                },
                child: const Text('Open Itinerary Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Itinerary Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Lưu vào chuyến đi'), findsOneWidget);
      expect(find.text('Hành trình Sài Gòn 2 ngày'), findsOneWidget);

      // Tap Save button for itinerary 101
      final saveBtn = find.widgetWithText(FilledButton, 'Lưu').first;
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify repository call
      expect(crudRepo.savedPlaceCalls.length, 1);
      expect(crudRepo.savedPlaceCalls.first['itineraryId'], 101);
      expect(crudRepo.savedPlaceCalls.first['placeId'], 10);
      expect(saveCallbackTriggered, isTrue);
      expect(savedItineraryId, 101);

      // Verify SnackBar confirmation
      expect(find.text('Đã lưu "Bảo tàng Chứng tích Chiến tranh" vào "Hành trình Sài Gòn 2 ngày"!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });

    testWidgets('handles 409 Conflict gracefully by displaying already-saved notice without crash', (tester) async {
      final crudRepo = E2ECrudRepository(
        itineraries: [sampleSummary],
        throwOnSavePlace: true,
        savePlaceException: ApiException(
          statusCode: 409,
          message: 'Địa điểm đã tồn tại trong lịch trình',
        ),
      );
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ItineraryPickerBottomSheet.show(
                    context,
                    place: sampleInternalPlace,
                    token: auth.token!,
                    repository: crudRepo,
                    authNotifier: auth,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, 'Lưu').first;
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify that 409 did not crash, but informed the user
      expect(
        find.text('Địa điểm này đã được lưu trong lịch trình "Hành trình Sài Gòn 2 ngày".'),
        findsOneWidget,
      );
      expect(find.text('Đã lưu'), findsOneWidget);
    });

    testWidgets('prevents double submission when saving to an itinerary', (tester) async {
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ItineraryPickerBottomSheet.show(
                    context,
                    place: sampleInternalPlace,
                    token: auth.token!,
                    repository: crudRepo,
                    authNotifier: auth,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Double tap save rapidly
      final saveBtn = find.widgetWithText(FilledButton, 'Lưu').first;
      await tester.tap(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Exactly one save request dispatched
      expect(crudRepo.savedPlaceCalls.length, 1);
    });
  });

  group('Phase 6A.3 - E2E Integration: Flow B (Schedule as Activity)', () {
    testWidgets('schedules Internal Place: sets canonicalPlaceId and forces null coordinates', (tester) async {
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final itinRepo = E2EItineraryRepository();
      itinRepo.detailsMap[101] = sampleDetail;
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityFormBottomSheet(
              itineraryId: 101,
              dayId: 201,
              dayNumber: 1,
              dayTitle: 'Khám phá văn hóa & lịch sử',
              authNotifier: auth,
              repository: crudRepo,
              initialLocation: sampleInternalPlace,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check pre-populated name
      expect(find.text('Bảo tàng Chứng tích Chiến tranh'), findsWidgets);

      // Submit activity
      final submitButton = find.widgetWithText(ElevatedButton, 'Thêm hoạt động');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(crudRepo.addActivityCalls.length, 1);
      final call = crudRepo.addActivityCalls.first;
      expect(call['itineraryId'], 101);
      expect(call['dayId'], 201);
      final req = call['request'] as CreateActivityRequest;
      expect(req.name, 'Bảo tàng Chứng tích Chiến tranh');
      expect(req.canonicalPlaceId, 10);
      expect(req.latitude, isNull);
      expect(req.longitude, isNull);
      expect(req.locationProvider, 'PLACE_CATALOG');
    });

    testWidgets('schedules External POI: sets coordinates, provider and leaves canonicalPlaceId null', (tester) async {
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityFormBottomSheet(
              itineraryId: 101,
              dayId: 202,
              dayNumber: 2,
              dayTitle: 'Ẩm thực & Mua sắm',
              authNotifier: auth,
              repository: crudRepo,
              initialLocation: sampleExternalPoi,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check pre-populated name
      expect(find.text('Nhà hàng Cơm Niêu Sài Gòn'), findsWidgets);

      // Submit activity
      final submitButton = find.widgetWithText(ElevatedButton, 'Thêm hoạt động');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(crudRepo.addActivityCalls.length, 1);
      final call = crudRepo.addActivityCalls.first;
      expect(call['itineraryId'], 101);
      expect(call['dayId'], 202);
      final req = call['request'] as CreateActivityRequest;
      expect(req.name, 'Nhà hàng Cơm Niêu Sài Gòn');
      expect(req.canonicalPlaceId, isNull);
      expect(req.latitude, 10.7780);
      expect(req.longitude, 106.6890);
      expect(req.locationProvider, 'TOMTOM');
      expect(req.placeId, 'tomtom_999');
    });

    testWidgets('blocks scheduling on itinerary with 0 days and displays notice', (tester) async {
      final crudRepo = E2ECrudRepository(itineraries: [zeroDaysSummary]);
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ItineraryPickerBottomSheet.showForSchedule(
                    context,
                    place: sampleInternalPlace,
                    token: auth.token!,
                    repository: crudRepo,
                    authNotifier: auth,
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

      await tester.tap(find.byKey(const Key('select_itinerary_102')));
      await tester.pumpAndSettle();

      // Stays on sheet and shows informative warning
      expect(
        find.text('Lịch trình này chưa có ngày nào. Vui lòng mở chi tiết lịch trình để thêm ngày trước.'),
        findsOneWidget,
      );
      expect(find.text('Lên lịch vào chuyến đi'), findsOneWidget);
    });
  });

  group('Phase 6A.3 - E2E Integration: LocationPickerSheet Integration & Lifecycle', () {
    testWidgets('LocationPickerSheet integrates both Flow A and Flow B for Internal Place', (tester) async {
      final locationRepo = E2ELocationRepository(searchResults: [sampleInternalPlace]);
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              repository: locationRepo,
              itineraryCrudRepository: crudRepo,
              authNotifier: auth,
              token: auth.token,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search place
      await tester.enterText(find.byType(TextField), 'Chứng tích');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Select result item
      await tester.tap(find.widgetWithText(ListTile, 'Bảo tàng Chứng tích Chiến tranh'));
      await tester.pumpAndSettle();

      // Both buttons must be rendered
      expect(find.byKey(const Key('save_to_itinerary_button')), findsOneWidget);
      expect(find.byKey(const Key('schedule_activity_button')), findsOneWidget);
    });

    testWidgets('LocationPickerSheet disables both Flow A and Flow B for Administrative Boundary', (tester) async {
      final locationRepo = E2ELocationRepository(searchResults: [sampleAdminBoundary]);
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final auth = E2EAuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              repository: locationRepo,
              itineraryCrudRepository: crudRepo,
              authNotifier: auth,
              token: auth.token,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Quận 3');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Quận 3'));
      await tester.pumpAndSettle();

      // Neither action button is rendered; informational banner is shown
      expect(find.byKey(const Key('save_to_itinerary_button')), findsNothing);
      expect(find.byKey(const Key('schedule_activity_button')), findsNothing);
      expect(
        find.text('Đây là ranh giới khu vực hành chính, không thể lưu vào lịch trình.'),
        findsOneWidget,
      );
    });

    test('LocationMapper enforces boundary exclusion with ArgumentError', () {
      expect(
        () => LocationActivityMapper.toCreateRequest(
          location: sampleAdminBoundary,
          name: 'Quận 3',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Phase 6A.3 - E2E Integration: Coexistence and Independence', () {
    testWidgets('Flow A and Flow B do not produce cross-side effects', (tester) async {
      final crudRepo = E2ECrudRepository(itineraries: [sampleSummary]);
      final auth = E2EAuthNotifier();

      // Execute Flow A
      await crudRepo.savePlaceToItinerary(101, 10, token: auth.token!);

      // Verify only savedPlaces called, zero addActivity calls
      expect(crudRepo.savedPlaceCalls.length, 1);
      expect(crudRepo.addActivityCalls.length, 0);

      // Execute Flow B
      final request = LocationActivityMapper.toCreateRequest(
        location: sampleInternalPlace,
        name: 'Bảo tàng Chứng tích Chiến tranh',
      );
      await crudRepo.addActivity(101, 201, request, token: auth.token);

      // Verify addActivity called, savedPlaces remains unchanged at 1
      expect(crudRepo.savedPlaceCalls.length, 1);
      expect(crudRepo.addActivityCalls.length, 1);
    });
  });
}
