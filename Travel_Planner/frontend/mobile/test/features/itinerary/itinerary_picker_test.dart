import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_place.dart';
import 'package:mobile/features/itinerary/data/models/place_summary.dart';
import 'package:mobile/features/itinerary/presentation/widgets/itinerary_picker_bottom_sheet.dart';
import 'package:mobile/features/location/data/location_repository.dart';
import 'package:mobile/features/location/data/models/location_search_result.dart';
import 'package:mobile/features/location/presentation/widgets/location_picker_sheet.dart';

class MockItineraryCrudRepository extends ItineraryCrudRepository {
  List<ItinerarySummary> itinerariesToReturn;
  bool throwOnGetItineraries;
  ApiException? getItinerariesException;
  int getMyItinerariesCallCount = 0;
  String? lastStatus;
  int? lastPage;
  int? lastSize;

  ApiException? saveException;
  int savePlaceCallCount = 0;
  int? lastSavedItineraryId;
  int? lastSavedPlaceId;
  String? lastSavedToken;

  MockItineraryCrudRepository({
    this.itinerariesToReturn = const [],
    this.throwOnGetItineraries = false,
    this.getItinerariesException,
    this.saveException,
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
    getMyItinerariesCallCount++;
    lastStatus = status;
    lastPage = page;
    lastSize = size;

    if (throwOnGetItineraries) {
      throw getItinerariesException ??
          ApiException(statusCode: 500, message: 'Server error');
    }

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
  Future<ItineraryPlace> savePlaceToItinerary(
    int itineraryId,
    int placeId, {
    required String token,
  }) async {
    savePlaceCallCount++;
    lastSavedItineraryId = itineraryId;
    lastSavedPlaceId = placeId;
    lastSavedToken = token;

    if (saveException != null) {
      throw saveException!;
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
}

class MockLocationRepository extends LocationRepository {
  List<LocationSearchResult> searchResultsToReturn;
  MockLocationRepository({this.searchResultsToReturn = const []});

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
  group('Phase 6A.1 - LocationSearchResult Type Classification Helpers', () {
    test('isInternalPlace and internalPlaceId correctly identify internal places', () {
      const internalPlace = LocationSearchResult(
        placeId: 'place_42',
        name: 'Dinh Độc Lập',
        formattedAddress: '135 Nam Kỳ Khởi Nghĩa, Phường Bến Thành, Quận 1',
        provider: 'SYSTEM',
        type: 'place',
        latitude: 10.7770,
        longitude: 106.6953,
      );

      expect(internalPlace.isInternalPlace, isTrue);
      expect(internalPlace.internalPlaceId, 42);
      expect(internalPlace.isAdministrativeArea, isFalse);
      expect(internalPlace.isExternalPoi, isFalse);
    });

    test('isAdministrativeArea correctly identifies administrative areas', () {
      const adminArea = LocationSearchResult(
        placeId: 'admin_79',
        name: 'Thành phố Hồ Chí Minh',
        formattedAddress: 'Việt Nam',
        provider: 'SYSTEM',
        type: 'administrative',
        category: 'boundary',
        isLocalityFallback: true,
        latitude: 10.7769,
        longitude: 106.7009,
      );

      expect(adminArea.isInternalPlace, isFalse);
      expect(adminArea.internalPlaceId, isNull);
      expect(adminArea.isAdministrativeArea, isTrue);
      expect(adminArea.isExternalPoi, isFalse);
    });

    test('isExternalPoi correctly identifies third-party external POIs', () {
      const externalPoi = LocationSearchResult(
        placeId: 'tomtom_poi_123',
        name: 'The Coffee House',
        formattedAddress: 'Nguyễn Thị Minh Khai, Quận 1',
        provider: 'TOMTOM',
        type: 'poi',
        latitude: 10.7800,
        longitude: 106.6900,
      );

      expect(externalPoi.isInternalPlace, isFalse);
      expect(externalPoi.internalPlaceId, isNull);
      expect(externalPoi.isAdministrativeArea, isFalse);
      expect(externalPoi.isExternalPoi, isTrue);
    });

    test('Manual pin coordinates are neither internal place nor admin area', () {
      const manualPin = LocationSearchResult(
        placeId: '',
        name: 'Vị trí đã ghim',
        formattedAddress: '10.75000, 106.65000',
        provider: 'MANUAL_PIN',
        latitude: 10.7500,
        longitude: 106.6500,
      );

      expect(manualPin.isInternalPlace, isFalse);
      expect(manualPin.internalPlaceId, isNull);
      expect(manualPin.isAdministrativeArea, isFalse);
      expect(manualPin.isExternalPoi, isTrue);
    });
  });

  group('Phase 6A.1 - ItineraryPickerBottomSheet Widget Tests', () {
    const samplePlace = LocationSearchResult(
      placeId: 'place_10',
      name: 'Bảo tàng Chứng tích Chiến tranh',
      formattedAddress: '28 Võ Văn Tần, Phường 6, Quận 3',
      provider: 'SYSTEM',
      type: 'place',
      latitude: 10.7794,
      longitude: 106.6923,
    );

    final sampleItineraries = [
      const ItinerarySummary(
        itineraryId: 101,
        title: 'Chuyến đi Đà Lạt 3N2Đ',
        location: 'Lâm Đồng, Việt Nam',
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        totalDays: 3,
        budget: 2500000,
        viewCount: 15,
        favoriteCount: 4,
        ratingCount: 2,
        averageRating: 4.5,
      ),
      const ItinerarySummary(
        itineraryId: 102,
        title: 'Khám phá ẩm thực Sài Gòn',
        location: 'TP. Hồ Chí Minh',
        visibility: 'PRIVATE',
        status: 'ACTIVE',
        totalDays: 2,
        budget: 1200000,
        viewCount: 8,
        favoriteCount: 1,
        ratingCount: 0,
        averageRating: 0.0,
      ),
    ];

    testWidgets('renders active itineraries list successfully', (tester) async {
      final repo = MockItineraryCrudRepository(
        itinerariesToReturn: sampleItineraries,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryPickerBottomSheet(
              place: samplePlace,
              token: 'test-token',
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(repo.getMyItinerariesCallCount, 1);
      expect(repo.lastStatus, 'ACTIVE');
      expect(find.text('Lưu vào chuyến đi'), findsOneWidget);
      expect(find.text('Bảo tàng Chứng tích Chiến tranh'), findsOneWidget);
      expect(find.text('Chuyến đi Đà Lạt 3N2Đ'), findsOneWidget);
      expect(find.text('Khám phá ẩm thực Sài Gòn'), findsOneWidget);
      expect(find.text('Công khai'), findsOneWidget);
      expect(find.text('Riêng tư'), findsOneWidget);
      expect(find.text('Lưu'), findsNWidgets(2));
    });

    testWidgets('displays empty state when user has no active itineraries', (tester) async {
      final repo = MockItineraryCrudRepository(itinerariesToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryPickerBottomSheet(
              place: samplePlace,
              token: 'test-token',
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa có lịch trình nào'), findsOneWidget);
      expect(find.text('Tạo lịch trình mới'), findsOneWidget);
    });

    testWidgets('displays error state and allows retry on failure', (tester) async {
      final repo = MockItineraryCrudRepository(
        throwOnGetItineraries: true,
        getItinerariesException: ApiException(
          statusCode: 500,
          message: 'Lỗi tải danh sách chuyến đi',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryPickerBottomSheet(
              place: samplePlace,
              token: 'test-token',
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lỗi tải danh sách chuyến đi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Now fix the repository and tap retry
      repo.throwOnGetItineraries = false;
      repo.itinerariesToReturn = sampleItineraries;

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(repo.getMyItinerariesCallCount, 2);
      expect(find.text('Chuyến đi Đà Lạt 3N2Đ'), findsOneWidget);
    });

    testWidgets('saving place successfully triggers API and shows saved state', (tester) async {
      final repo = MockItineraryCrudRepository(
        itinerariesToReturn: sampleItineraries,
      );
      int? savedItineraryId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryPickerBottomSheet(
              place: samplePlace,
              token: 'test-token',
              repository: repo,
              onSaved: (id) => savedItineraryId = id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Lưu').first;
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.savePlaceCallCount, 1);
      expect(repo.lastSavedItineraryId, 101);
      expect(repo.lastSavedPlaceId, 10);
      expect(repo.lastSavedToken, 'test-token');
      expect(savedItineraryId, 101);
      expect(find.text('Đã lưu'), findsOneWidget);
      expect(
        find.text('Đã lưu "Bảo tàng Chứng tích Chiến tranh" vào "Chuyến đi Đà Lạt 3N2Đ"!'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });

    testWidgets('handles 409 Conflict gracefully by notifying user place is already saved', (tester) async {
      final repo = MockItineraryCrudRepository(
        itinerariesToReturn: sampleItineraries,
        saveException: ApiException(
          statusCode: 409,
          message: 'Địa điểm này đã được lưu trong lịch trình.',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryPickerBottomSheet(
              place: samplePlace,
              token: 'test-token',
              repository: repo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Lưu').first;
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.savePlaceCallCount, 1);
      expect(
        find.text('Địa điểm này đã được lưu trong lịch trình "Chuyến đi Đà Lạt 3N2Đ".'),
        findsOneWidget,
      );
      expect(find.text('Đã lưu'), findsOneWidget);
    });
  });

  group('Phase 6A.1 - LocationPickerSheet Save Place Actions Integration', () {
    testWidgets('renders active Save to Itinerary button when Internal Place is selected', (tester) async {
      const internalPlace = LocationSearchResult(
        placeId: 'place_99',
        name: 'Chợ Bến Thành',
        formattedAddress: 'Quận 1, TP. Hồ Chí Minh',
        provider: 'SYSTEM',
        type: 'place',
        latitude: 10.7725,
        longitude: 106.6980,
      );

      final fakeLocationRepo = MockLocationRepository(
        searchResultsToReturn: [internalPlace],
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

      // Enter search text to trigger results
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Bến Thành');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Search results list should show bookmark icon for internal place
      expect(find.byKey(const Key('save_result_place_99')), findsOneWidget);

      // Select the result
      await tester.tap(find.widgetWithText(ListTile, 'Chợ Bến Thành'));
      await tester.pumpAndSettle();

      // The selected location details card should show the active Save to Itinerary button
      expect(find.byKey(const Key('save_to_itinerary_button')), findsOneWidget);
      expect(find.text('Lưu vào chuyến đi'), findsOneWidget);
    });

    testWidgets('displays disabled notice for external POI', (tester) async {
      const externalPoi = LocationSearchResult(
        placeId: 'tomtom_99',
        name: 'Quán ăn ngon',
        formattedAddress: 'Quận 1, TP. Hồ Chí Minh',
        provider: 'TOMTOM',
        type: 'poi',
        latitude: 10.7700,
        longitude: 106.6900,
      );

      final fakeLocationRepo = MockLocationRepository(
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
      await tester.enterText(searchInput, 'Quán ăn');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Select external POI
      await tester.tap(find.widgetWithText(ListTile, 'Quán ăn ngon'));
      await tester.pumpAndSettle();

      // Should show external POI explanation notice
      expect(
        find.text(
          'Địa điểm này chưa có trong danh mục địa điểm của Travel Planner. Bạn vẫn có thể lên lịch trực tiếp vào một ngày trong chuyến đi.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('save_to_itinerary_button')), findsNothing);
    });

    testWidgets('displays disabled notice for administrative boundary', (tester) async {
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

      final fakeLocationRepo = MockLocationRepository(
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

      // Select admin area
      await tester.tap(find.widgetWithText(ListTile, 'Quận 1'));
      await tester.pumpAndSettle();

      // Should show administrative boundary notice
      expect(
        find.text(
          'Đây là ranh giới khu vực hành chính, không thể lưu vào lịch trình.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('save_to_itinerary_button')), findsNothing);
    });
  });
}
