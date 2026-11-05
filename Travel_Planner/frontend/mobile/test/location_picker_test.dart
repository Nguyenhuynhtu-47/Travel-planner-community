import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/create_activity_request.dart';
import 'package:mobile/features/itinerary/data/models/destination_summary.dart';
import 'package:mobile/features/itinerary/data/models/update_activity_request.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_form_dialog.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_timeline_item.dart';
import 'package:mobile/features/location/data/location_repository.dart';
import 'package:mobile/features/location/data/models/location_search_result.dart';
import 'package:mobile/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:mobile/shared/widgets/app_map_view.dart';

class FakeLocationRepository extends LocationRepository {
  List<LocationSearchResult> searchResultsToReturn;
  LocationSearchResult? reverseGeocodeResultToReturn;
  ApiException? exceptionToThrow;
  int searchCallCount = 0;
  String? lastSearchQuery;
  int reverseGeocodeCallCount = 0;
  double? lastReverseLat;
  double? lastReverseLng;

  FakeLocationRepository({
    this.searchResultsToReturn = const [],
    this.reverseGeocodeResultToReturn,
    this.exceptionToThrow,
  });

  @override
  Future<List<LocationSearchResult>> searchLocations(
    String query, {
    int? limit,
    double? latitude,
    double? longitude,
    String? token,
  }) async {
    searchCallCount++;
    lastSearchQuery = query;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return searchResultsToReturn;
  }

  @override
  Future<LocationSearchResult?> reverseGeocode(
    double latitude,
    double longitude, {
    String? token,
  }) async {
    reverseGeocodeCallCount++;
    lastReverseLat = latitude;
    lastReverseLng = longitude;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return reverseGeocodeResultToReturn;
  }
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  String? get token => 'test-token-123';

  @override
  bool get isAuthenticated => true;
}

class FakeItineraryCrudRepository extends ItineraryCrudRepository {
  List<DestinationSummary> destinations;
  CreateActivityRequest? lastCreateRequest;
  UpdateActivityRequest? lastUpdateRequest;

  FakeItineraryCrudRepository({this.destinations = const []});

  @override
  Future<List<DestinationSummary>> getDestinations({
    String? keyword,
    String? token,
  }) async {
    return destinations;
  }

  @override
  Future<ActivityDetail> addActivity(
    int itineraryId,
    int dayId,
    CreateActivityRequest request, {
    String? token,
  }) async {
    lastCreateRequest = request;
    return ActivityDetail(
      activityId: 100,
      name: request.name,
      displayOrder: 1,
      customLocationName: request.customLocationName,
      customAddress: request.customAddress,
      latitude: request.latitude,
      longitude: request.longitude,
      placeId: request.placeId,
      locationProvider: request.locationProvider,
    );
  }

  @override
  Future<ActivityDetail> updateActivity(
    int itineraryId,
    int dayId,
    int activityId,
    UpdateActivityRequest request, {
    String? token,
  }) async {
    lastUpdateRequest = request;
    return ActivityDetail(
      activityId: activityId,
      name: request.name,
      displayOrder: 1,
      customLocationName: request.customLocationName,
      customAddress: request.customAddress,
      latitude: request.latitude,
      longitude: request.longitude,
      placeId: request.placeId,
      locationProvider: request.locationProvider,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 - CustomLocationResult Model', () {
    test('Constructs directly with provided attributes', () {
      const result = CustomLocationResult(
        locationName: 'Quán Bún Bò Huế',
        address: '19 Nguyễn Huệ, Quận 1',
        latitude: 10.7731,
        longitude: 106.7032,
        placeId: 'osm-way-99',
        locationProvider: 'LOCATION_IQ',
      );

      expect(result.locationName, 'Quán Bún Bò Huế');
      expect(result.address, '19 Nguyễn Huệ, Quận 1');
      expect(result.latitude, 10.7731);
      expect(result.longitude, 106.7032);
      expect(result.placeId, 'osm-way-99');
      expect(result.locationProvider, 'LOCATION_IQ');
      expect(result.toString(), contains('Quán Bún Bò Huế'));
    });

    test(
      'fromSearchResult factory converts LocationSearchResult correctly',
      () {
        const searchResult = LocationSearchResult(
          placeId: 'place-77',
          name: 'Hồ Gươm',
          formattedAddress: 'Hoàn Kiếm, Hà Nội, Việt Nam',
          latitude: 21.0285,
          longitude: 105.8544,
          provider: 'LOCATION_IQ',
        );

        final custom = CustomLocationResult.fromSearchResult(searchResult);
        expect(custom.locationName, 'Hồ Gươm');
        expect(custom.address, 'Hoàn Kiếm, Hà Nội, Việt Nam');
        expect(custom.latitude, 21.0285);
        expect(custom.longitude, 105.8544);
        expect(custom.placeId, 'place-77');
        expect(custom.locationProvider, 'LOCATION_IQ');
      },
    );

    test(
      'fromSearchResult uses fallback name when search result name is empty',
      () {
        const searchResult = LocationSearchResult(
          placeId: '',
          name: '',
          formattedAddress: '',
          latitude: 16.0,
          longitude: 108.0,
        );

        final custom = CustomLocationResult.fromSearchResult(searchResult);
        expect(custom.locationName, 'Vị trí đã ghim');
        expect(custom.address, isNull);
        expect(custom.placeId, isNull);
        expect(custom.locationProvider, 'LOCATION_IQ');
      },
    );
  });

  group('Phase 4 - LocationPickerSheet Widget Tests', () {
    testWidgets(
      'Renders search input, map, and initial hint when no center is provided',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeLocationRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LocationPickerSheet(repository: fakeRepo)),
          ),
        );

        expect(find.text('Chọn vị trí trên bản đồ'), findsOneWidget);
        expect(
          find.text('Tìm kiếm địa điểm (tối thiểu 2 ký tự)...'),
          findsOneWidget,
        );
        expect(find.byType(AppMapView), findsOneWidget);
        expect(
          find.text('Chạm vào bản đồ để thả ghim hoặc tìm kiếm địa điểm'),
          findsOneWidget,
        );
        expect(find.text('Hủy'), findsOneWidget);
        expect(find.text('Xác nhận vị trí'), findsOneWidget);

        // Confirm button is disabled because no location is selected
        final confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Xác nhận vị trí'),
        );
        expect(confirmBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Renders initial marker and enables confirm button when initialCenter is passed',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeLocationRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerSheet(
                repository: fakeRepo,
                initialCenter: const LatLng(10.77, 106.69),
                initialName: 'Dinh Độc Lập',
                initialAddress: '135 Nam Kỳ Khởi Nghĩa',
              ),
            ),
          ),
        );

        expect(find.text('Dinh Độc Lập'), findsOneWidget);
        expect(find.text('135 Nam Kỳ Khởi Nghĩa'), findsOneWidget);

        // Confirm button is enabled
        final confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Xác nhận vị trí'),
        );
        expect(confirmBtn.onPressed, isNotNull);
      },
    );

    testWidgets('Search query under 2 chars does not call searchLocations', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeLocationRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocationPickerSheet(repository: fakeRepo)),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'H');
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeRepo.searchCallCount, 0);
    });

    testWidgets(
      'Debounced search query calls searchLocations and displays results',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeLocationRepository(
          searchResultsToReturn: [
            const LocationSearchResult(
              placeId: 'loc-1',
              name: 'Hồ Hoàn Kiếm',
              formattedAddress: 'Hoàn Kiếm, Hà Nội',
              latitude: 21.0285,
              longitude: 105.8544,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerSheet(
                repository: fakeRepo,
                locationContext: 'Hà Nội',
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField).first, 'Hồ Hoàn Kiếm');
        // Wait for 400ms debounce
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();

        expect(fakeRepo.searchCallCount, 1);
        expect(fakeRepo.lastSearchQuery, 'Hồ Hoàn Kiếm, Hà Nội');
        expect(find.text('Hồ Hoàn Kiếm'), findsWidgets);
        expect(find.text('Hoàn Kiếm, Hà Nội'), findsOneWidget);

        // Tapping a search result item selects it
        await tester.tap(find.text('Hồ Hoàn Kiếm').last);
        await tester.pumpAndSettle();

        // Location details card now displays the selected place
        expect(find.text('Hoàn Kiếm, Hà Nội'), findsOneWidget);
        final confirmBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Xác nhận vị trí'),
        );
        expect(confirmBtn.onPressed, isNotNull);
      },
    );

    testWidgets('Search handles HTTP 429 rate limit error gracefully', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeLocationRepository(
        exceptionToThrow: ApiException(
          statusCode: 429,
          message: 'Too many requests',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocationPickerSheet(repository: fakeRepo)),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Bến Thành');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(
        find.text('Đã vượt quá giới hạn tìm kiếm, vui lòng thử lại sau.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Search handles generic network error gracefully without crashing',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeLocationRepository(
          exceptionToThrow: ApiException(
            statusCode: 500,
            message: 'Network socket timeout',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LocationPickerSheet(repository: fakeRepo)),
          ),
        );

        await tester.enterText(find.byType(TextField).first, 'Chợ Lớn');
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();

        expect(find.text('Network socket timeout'), findsOneWidget);
      },
    );

    testWidgets('Tapping map drops pin and sets fallback name Vị trí đã ghim', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeLocationRepository(
        reverseGeocodeResultToReturn: const LocationSearchResult(
          placeId: 'rev-1',
          name: 'Nhà Thờ Đức Bà',
          formattedAddress: '01 Công Xã Paris, Bến Nghé, Quận 1',
          latitude: 10.7797,
          longitude: 106.6990,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocationPickerSheet(repository: fakeRepo)),
        ),
      );

      // Tap on the map
      await tester.tap(find.byType(AppMapView));
      await tester.pump(const Duration(milliseconds: 300));

      // Zero-API resilience: Confirm button immediately enabled!
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Xác nhận vị trí'),
      );
      expect(confirmBtn.onPressed, isNotNull);

      // Once reverse geocode resolves:
      await tester.pumpAndSettle();
      expect(fakeRepo.reverseGeocodeCallCount, 1);
      expect(find.text('Vị trí đã ghim'), findsOneWidget);
      expect(find.text('01 Công Xã Paris, Bến Nghé, Quận 1'), findsOneWidget);
    });

    testWidgets(
      'Reverse geocode failure preserves fallback label Vị trí đã ghim and allows confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeLocationRepository(
          exceptionToThrow: ApiException(
            statusCode: 404,
            message: 'Reverse geocode failed',
          ),
        );

        CustomLocationResult? confirmedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    confirmedResult = await showLocationPickerSheet(
                      ctx,
                      repository: fakeRepo,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Tap map
        await tester.tap(find.byType(AppMapView));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Label remains fallback "Vị trí đã ghim"
        expect(find.text('Vị trí đã ghim'), findsOneWidget);

        // Confirm button is enabled and taps successfully
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Xác nhận vị trí'),
        );
        await tester.pumpAndSettle();

        expect(confirmedResult, isNotNull);
        expect(confirmedResult!.locationName, 'Vị trí đã ghim');
        expect(confirmedResult!.locationProvider, 'MANUAL_PIN');
      },
    );

    testWidgets('Tapping Hủy pops sheet returning null', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeLocationRepository();
      CustomLocationResult? confirmedResult = const CustomLocationResult(
        locationName: 'dummy',
        latitude: 0,
        longitude: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  confirmedResult = await showLocationPickerSheet(
                    ctx,
                    repository: fakeRepo,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(confirmedResult, isNull);
    });

    testWidgets(
      'Editing location name via dialog updates custom location name',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeLocationRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerSheet(
                repository: fakeRepo,
                initialCenter: const LatLng(10.5, 106.5),
                initialName: 'Vị trí đã ghim',
              ),
            ),
          ),
        );

        expect(find.text('Vị trí đã ghim'), findsOneWidget);

        // Tap edit icon
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Đổi tên vị trí'), findsOneWidget);

        // Enter custom name
        await tester.enterText(
          find.byType(TextField).last,
          'Quán Cà Phê Góc Phố',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
        await tester.pumpAndSettle();

        expect(find.text('Quán Cà Phê Góc Phố'), findsOneWidget);
      },
    );
  });

  group('Phase 4 - ActivityFormBottomSheet Location Integration Tests', () {
    testWidgets(
      'ActivityFormBottomSheet shows map picker button and saves custom location',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeCrudRepo = FakeItineraryCrudRepository();
        final fakeLocRepo = FakeLocationRepository(
          reverseGeocodeResultToReturn: const LocationSearchResult(
            placeId: 'loc-42',
            name: 'Quán Ăn Ngon',
            formattedAddress: '18 Phan Bội Châu, Hà Nội',
            latitude: 21.0267,
            longitude: 105.8433,
          ),
        );
        final fakeAuth = FakeAuthNotifier();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showActivityFormDialog(
                    ctx,
                    itineraryId: 1,
                    dayId: 1,
                    dayNumber: 1,
                    authNotifier: fakeAuth,
                    repository: fakeCrudRepo,
                    locationRepository: fakeLocRepo,
                  ),
                  child: const Text('Open Form'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Form'));
        await tester.pumpAndSettle();

        // Check map picker button
        expect(find.text('Chọn vị trí trên bản đồ'), findsOneWidget);

        // Open map picker
        await tester.tap(find.text('Chọn vị trí trên bản đồ'));
        await tester.pumpAndSettle();

        // Tap map inside location picker sheet
        expect(find.byType(LocationPickerSheet), findsOneWidget);
        await tester.tap(find.byType(AppMapView));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Confirm picked location
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Xác nhận vị trí'),
        );
        await tester.pumpAndSettle();

        // Picker sheet is closed, form shows custom location card
        expect(find.byType(LocationPickerSheet), findsNothing);
        expect(find.text('Vị trí đã ghim'), findsWidgets);
        expect(find.text('18 Phan Bội Châu, Hà Nội'), findsOneWidget);

        // Enter activity name and submit
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tên hoạt động *'),
          'Ăn trưa Quán Ngon',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm hoạt động'));
        await tester.pumpAndSettle();

        expect(fakeCrudRepo.lastCreateRequest, isNotNull);
        expect(fakeCrudRepo.lastCreateRequest!.name, 'Ăn trưa Quán Ngon');
        expect(
          fakeCrudRepo.lastCreateRequest!.customLocationName,
          'Vị trí đã ghim',
        );
        expect(
          fakeCrudRepo.lastCreateRequest!.customAddress,
          '18 Phan Bội Châu, Hà Nội',
        );
        expect(
          fakeCrudRepo.lastCreateRequest!.latitude,
          closeTo(14.0583, 0.01),
        );
        expect(
          fakeCrudRepo.lastCreateRequest!.longitude,
          closeTo(108.2772, 0.01),
        );
        expect(fakeCrudRepo.lastCreateRequest!.destinationId, isNull);
      },
    );

    testWidgets(
      'Editing activity preserves existing custom location on normal edit',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final initialActivity = const ActivityDetail(
          activityId: 55,
          name: 'Hoạt động đã có vị trí',
          displayOrder: 1,
          customLocationName: 'Cà phê Giảng',
          customAddress: '39 Nguyễn Hữu Huân, Hà Nội',
          latitude: 21.0333,
          longitude: 105.8540,
          placeId: 'node-cafe-1',
          locationProvider: 'LOCATION_IQ',
        );

        final fakeCrudRepo = FakeItineraryCrudRepository();
        final fakeLocRepo = FakeLocationRepository();
        final fakeAuth = FakeAuthNotifier();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showActivityFormDialog(
                    ctx,
                    itineraryId: 1,
                    dayId: 1,
                    dayNumber: 1,
                    initialActivity: initialActivity,
                    authNotifier: fakeAuth,
                    repository: fakeCrudRepo,
                    locationRepository: fakeLocRepo,
                  ),
                  child: const Text('Open Edit Form'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Edit Form'));
        await tester.pumpAndSettle();

        // Custom location is loaded and displayed
        expect(find.text('Cà phê Giảng'), findsOneWidget);
        expect(find.text('39 Nguyễn Hữu Huân, Hà Nội'), findsOneWidget);

        // Modify only activity name
        final nameField = find.widgetWithText(TextFormField, 'Tên hoạt động *');
        await tester.enterText(nameField, 'Uống cà phê trứng Giảng');

        // Save changes
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
        await tester.pumpAndSettle();

        expect(fakeCrudRepo.lastUpdateRequest, isNotNull);
        expect(fakeCrudRepo.lastUpdateRequest!.name, 'Uống cà phê trứng Giảng');
        expect(
          fakeCrudRepo.lastUpdateRequest!.customLocationName,
          'Cà phê Giảng',
        );
        expect(
          fakeCrudRepo.lastUpdateRequest!.customAddress,
          '39 Nguyễn Hữu Huân, Hà Nội',
        );
        expect(fakeCrudRepo.lastUpdateRequest!.latitude, 21.0333);
        expect(fakeCrudRepo.lastUpdateRequest!.longitude, 105.8540);
        expect(fakeCrudRepo.lastUpdateRequest!.destinationId, isNull);
      },
    );

    testWidgets(
      'Selecting a catalog destination clears custom location fields (State 1)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final initialActivity = const ActivityDetail(
          activityId: 55,
          name: 'Hoạt động có custom location',
          displayOrder: 1,
          customLocationName: 'Vị trí cũ',
          latitude: 10.0,
          longitude: 106.0,
        );

        final fakeCrudRepo = FakeItineraryCrudRepository(
          destinations: const [
            DestinationSummary(
              destinationId: 99,
              name: 'Điểm Đến Danh Mục',
              address: 'Địa chỉ mẫu',
            ),
          ],
        );
        final fakeLocRepo = FakeLocationRepository();
        final fakeAuth = FakeAuthNotifier();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showActivityFormDialog(
                    ctx,
                    itineraryId: 1,
                    dayId: 1,
                    dayNumber: 1,
                    initialActivity: initialActivity,
                    authNotifier: fakeAuth,
                    repository: fakeCrudRepo,
                    locationRepository: fakeLocRepo,
                  ),
                  child: const Text('Open Edit Form'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Edit Form'));
        await tester.pumpAndSettle();

        expect(find.text('Vị trí cũ'), findsOneWidget);

        // Open dropdown and pick catalog destination
        await tester.tap(find.text('Không liên kết địa điểm'));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Điểm Đến Danh Mục').last);
        await tester.pumpAndSettle();

        // Custom location card disappears!
        expect(find.text('Vị trí cũ'), findsNothing);

        // Save changes
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
        await tester.pumpAndSettle();

        expect(fakeCrudRepo.lastUpdateRequest, isNotNull);
        expect(fakeCrudRepo.lastUpdateRequest!.destinationId, 99);
        expect(fakeCrudRepo.lastUpdateRequest!.customLocationName, isNull);
        expect(fakeCrudRepo.lastUpdateRequest!.latitude, isNull);
        expect(fakeCrudRepo.lastUpdateRequest!.longitude, isNull);
      },
    );

    testWidgets(
      'Clearing custom location transitions activity to No Location (State 3)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final initialActivity = const ActivityDetail(
          activityId: 55,
          name: 'Hoạt động có custom location',
          displayOrder: 1,
          customLocationName: 'Vị trí cần xóa',
          latitude: 10.0,
          longitude: 106.0,
        );

        final fakeCrudRepo = FakeItineraryCrudRepository();
        final fakeLocRepo = FakeLocationRepository();
        final fakeAuth = FakeAuthNotifier();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showActivityFormDialog(
                    ctx,
                    itineraryId: 1,
                    dayId: 1,
                    dayNumber: 1,
                    initialActivity: initialActivity,
                    authNotifier: fakeAuth,
                    repository: fakeCrudRepo,
                    locationRepository: fakeLocRepo,
                  ),
                  child: const Text('Open Edit Form'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Edit Form'));
        await tester.pumpAndSettle();

        expect(find.text('Vị trí cần xóa'), findsOneWidget);

        // Tap delete icon on custom location card
        await tester.tap(find.byTooltip('Xóa vị trí'));
        await tester.pumpAndSettle();

        // Custom location card removed, button reappears
        expect(find.text('Vị trí cần xóa'), findsNothing);
        expect(find.text('Chọn vị trí trên bản đồ'), findsOneWidget);

        // Save changes
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
        await tester.pumpAndSettle();

        expect(fakeCrudRepo.lastUpdateRequest, isNotNull);
        expect(fakeCrudRepo.lastUpdateRequest!.destinationId, isNull);
        expect(fakeCrudRepo.lastUpdateRequest!.customLocationName, isNull);
        expect(fakeCrudRepo.lastUpdateRequest!.latitude, isNull);
        expect(fakeCrudRepo.lastUpdateRequest!.longitude, isNull);
      },
    );
  });

  group('Phase 4 - ActivityTimelineItem Custom Location Display', () {
    testWidgets(
      'ActivityTimelineItem renders custom location card when destination is null',
      (tester) async {
        const activity = ActivityDetail(
          activityId: 1,
          name: 'Check-in ngọn hải đăng',
          displayOrder: 1,
          customLocationName: 'Hải Đăng Vũng Tàu',
          customAddress: 'Đỉnh núi Nhỏ, Vũng Tàu',
          latitude: 10.3341,
          longitude: 107.0745,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ActivityTimelineItem(activity: activity)),
          ),
        );

        expect(find.text('Check-in ngọn hải đăng'), findsOneWidget);
        expect(find.text('Hải Đăng Vũng Tàu'), findsOneWidget);
        expect(find.text('Đỉnh núi Nhỏ, Vũng Tàu'), findsOneWidget);
        expect(find.byIcon(Icons.pin_drop), findsOneWidget);
      },
    );

    testWidgets(
      'ActivityTimelineItem renders fallback label Vị trí đã ghim when customLocationName is null',
      (tester) async {
        const activity = ActivityDetail(
          activityId: 2,
          name: 'Ghé điểm dừng chân',
          displayOrder: 1,
          latitude: 11.95,
          longitude: 108.45,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ActivityTimelineItem(activity: activity)),
          ),
        );

        expect(find.text('Ghé điểm dừng chân'), findsOneWidget);
        expect(find.text('Vị trí đã ghim'), findsOneWidget);
        expect(find.text('11.9500, 108.4500'), findsOneWidget);
      },
    );
  });

  group('Phase 4 - Dynamic Destination Context Resolution & POI Query Formatting', () {
    test('LocationSearchResult isCityOrAdministrative correctly identifies regions vs POIs', () {
      const cityResult = LocationSearchResult(
        placeId: '1',
        name: 'Đà Lạt',
        formattedAddress: 'Đà Lạt, Lâm Đồng',
        type: 'city',
        category: 'place',
      );
      expect(cityResult.isCityOrAdministrative, isTrue);

      const adminResult = LocationSearchResult(
        placeId: '2',
        name: 'Quận 1',
        formattedAddress: 'Quận 1, TP. Hồ Chí Minh',
        type: 'administrative',
        category: 'boundary',
      );
      expect(adminResult.isCityOrAdministrative, isTrue);

      const poiResult = LocationSearchResult(
        placeId: '3',
        name: 'Cà phê Tùng',
        formattedAddress: 'Khu Hoà Bình, Phường 1, Đà Lạt',
        type: 'cafe',
        category: 'amenity',
      );
      expect(poiResult.isCityOrAdministrative, isFalse);
    });

    test('formatQueryWithContext preserves POI queries containing district or ward qualifiers', () {
      const city = 'Thành phố Hồ Chí Minh';
      // Queries specifying district / ward should not have city string appended to prevent over-constraining POIs
      expect(
        LocationPickerSheet.formatQueryWithContext('tiệm bánh Quận 1', city),
        'tiệm bánh Quận 1',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('quán cafe quan 3', city),
        'quán cafe quan 3',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('nhà thuốc phường Bến Nghé', city),
        'nhà thuốc phường Bến Nghé',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('siêu thị huyện Củ Chi', city),
        'siêu thị huyện Củ Chi',
      );
    });

    test('formatQueryWithContext preserves POI queries containing spatial prepositions or commas', () {
      const city = 'Thành phố Hồ Chí Minh';
      expect(
        LocationPickerSheet.formatQueryWithContext('quán cà phê gần Bến Thành', city),
        'quán cà phê gần Bến Thành',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('tiệm bánh ở Nhà Thờ Đức Bà', city),
        'tiệm bánh ở Nhà Thờ Đức Bà',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('bệnh viện tại Nguyễn Trãi', city),
        'bệnh viện tại Nguyễn Trãi',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('Highlands Coffee, Lê Lợi', city),
        'Highlands Coffee, Lê Lợi',
      );
    });

    test('formatQueryWithContext appends city context for bare POI searches', () {
      const city = 'Thành phố Hồ Chí Minh';
      expect(
        LocationPickerSheet.formatQueryWithContext('tiệm bánh', city),
        'tiệm bánh, Thành phố Hồ Chí Minh',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('quán cà phê', city),
        'quán cà phê, Thành phố Hồ Chí Minh',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('Starbucks', city),
        'Starbucks, Thành phố Hồ Chí Minh',
      );
    });

    test('formatQueryWithContext preserves administrative and province queries without appending context', () {
      const city = 'An Giang';
      expect(
        LocationPickerSheet.formatQueryWithContext('Lâm Đồng', city),
        'Lâm Đồng',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('tỉnh Lâm Đồng', city),
        'tỉnh Lâm Đồng',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('Đà Lạt', city),
        'Đà Lạt',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('Quận 1', city),
        'Quận 1',
      );
      expect(
        LocationPickerSheet.formatQueryWithContext('Hà Nội', city),
        'Hà Nội',
      );
    });

    test('formatQueryWithContext does not duplicate context if query already includes it', () {
      expect(
        LocationPickerSheet.formatQueryWithContext('tiệm bánh Hồ Chí Minh', 'Thành phố Hồ Chí Minh'),
        'tiệm bánh Hồ Chí Minh',
      );
    });

    testWidgets(
      'LocationPickerSheet uses formatQueryWithContext when searching with locationContext',
      (tester) async {
        final fakeRepo = FakeLocationRepository(
          searchResultsToReturn: [
            const LocationSearchResult(
              placeId: 'dalat-cafe-1',
              name: 'Cà phê Tùng',
              formattedAddress: 'Khu Hoà Bình, Đà Lạt',
              latitude: 11.9404,
              longitude: 108.4583,
              type: 'cafe',
              category: 'amenity',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerSheet(
                repository: fakeRepo,
                locationContext: 'Đà Lạt',
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField).first, 'quán cà phê');
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();

        expect(fakeRepo.searchCallCount, 1);
        expect(fakeRepo.lastSearchQuery, 'quán cà phê, Đà Lạt');
        expect(find.text('Cà phê Tùng'), findsWidgets);
      },
    );
  });
}
