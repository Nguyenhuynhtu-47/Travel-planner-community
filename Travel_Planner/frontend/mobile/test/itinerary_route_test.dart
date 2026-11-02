import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:flutter_map/flutter_map.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/destination_summary.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/route_models.dart';
import 'package:mobile/features/itinerary/data/route_repository.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_map_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/navigation_launcher_helper.dart';
import 'package:url_launcher/url_launcher.dart';

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
          ),
          ActivityDetail(
            activityId: 1003,
            name: 'Cà phê Tùng',
            displayOrder: 3,
            startTime: '10:30',
            endTime: '12:00',
            estimatedCost: 60000.0,
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
      // Day 2: 1 activity with coordinates
      ItineraryDayDetail(
        dayId: 102,
        dayNumber: 2,
        title: 'Ngày 2: Quảng trường Lâm Viên',
        activities: [
          const ActivityDetail(
            activityId: 2001,
            name: 'Quảng trường Lâm Viên',
            customLocationName: 'Quảng trường Lâm Viên',
            customAddress: 'Trần Quốc Toản, Đà Lạt',
            latitude: 11.9360,
            longitude: 108.4450,
            displayOrder: 1,
          ),
        ],
      ),
      // Day 3: Empty day
      ItineraryDayDetail(
        dayId: 103,
        dayNumber: 3,
        title: 'Ngày 3: Tạm biệt Đà Lạt',
        activities: [],
      ),
    ],
  );

  group('Phase 6 - Route Models Tests', () {
    test('RouteResponse parses successful ACTUAL_ROAD JSON and inverts coordinates to LatLng', () {
      final json = {
        'itineraryId': 10,
        'dayId': 101,
        'status': 'SUCCESS',
        'routeType': 'ACTUAL_ROAD',
        'mode': 'driving-car',
        'totalDistanceMeters': 4200.5,
        'totalDurationSeconds': 450.0,
        'directDistanceMeters': 3100.0,
        'geometryCoordinates': [
          [108.4382, 11.9431], // [lon, lat]
          [108.4385, 11.9404],
        ],
        'waypoints': [
          {
            'activityId': 1001,
            'name': 'Hôtel Colline',
            'latitude': 11.9431,
            'longitude': 108.4382,
            'displayOrder': 1,
          },
          {
            'activityId': 1003,
            'name': 'Quán Cà Phê Tùng',
            'latitude': 11.9404,
            'longitude': 108.4385,
            'displayOrder': 3,
          },
        ],
      };

      final response = RouteResponse.fromJson(json);

      expect(response.itineraryId, 10);
      expect(response.dayId, 101);
      expect(response.status, 'SUCCESS');
      expect(response.routeType, 'ACTUAL_ROAD');
      expect(response.isRoadRoute, isTrue);
      expect(response.isFallback, isFalse);
      expect(response.isInsufficientWaypoints, isFalse);
      expect(response.totalDistanceMeters, 4200.5);
      expect(response.totalDurationSeconds, 450.0);
      expect(response.directDistanceMeters, 3100.0);

      // GeoJSON [lon, lat] must convert to LatLng(lat, lon)
      final points = response.polylinePoints;
      expect(points.length, 2);
      expect(points[0].latitude, 11.9431);
      expect(points[0].longitude, 108.4382);
      expect(points[1].latitude, 11.9404);
      expect(points[1].longitude, 108.4385);

      // Formatters
      expect(response.formattedRoadDistance, '4.2 km');
      expect(response.formattedDirectDistance, '3.1 km');
      expect(response.formattedDuration, '8 phút');
    });

    test('RouteResponse parses ESTIMATED_INDICATIVE fallback JSON with null road metrics and empty geometry', () {
      final json = {
        'itineraryId': 10,
        'dayId': 101,
        'status': 'FALLBACK',
        'routeType': 'ESTIMATED_INDICATIVE',
        'mode': 'driving-car',
        'totalDistanceMeters': null,
        'totalDurationSeconds': null,
        'directDistanceMeters': 850.0,
        'geometryCoordinates': [],
        'waypoints': [],
      };

      final response = RouteResponse.fromJson(json);

      expect(response.isRoadRoute, isFalse);
      expect(response.isFallback, isTrue);
      expect(response.totalDistanceMeters, isNull);
      expect(response.totalDurationSeconds, isNull);
      expect(response.directDistanceMeters, 850.0);
      expect(response.geometryCoordinates, isEmpty);
      expect(response.polylinePoints, isEmpty);
      expect(response.formattedRoadDistance, '');
      expect(response.formattedDuration, '');
      expect(response.formattedDirectDistance, '850 m');
    });

    test('RouteResponse parses INSUFFICIENT_WAYPOINTS JSON with null distances', () {
      final json = {
        'itineraryId': 10,
        'dayId': 102,
        'status': 'INSUFFICIENT_WAYPOINTS',
        'routeType': 'NONE',
        'mode': 'driving-car',
        'totalDistanceMeters': null,
        'totalDurationSeconds': null,
        'directDistanceMeters': null,
        'geometryCoordinates': [],
        'waypoints': [],
      };

      final response = RouteResponse.fromJson(json);

      expect(response.isInsufficientWaypoints, isTrue);
      expect(response.isRoadRoute, isFalse);
      expect(response.isFallback, isFalse);
      expect(response.totalDistanceMeters, isNull);
      expect(response.directDistanceMeters, isNull);
      expect(response.formattedDirectDistance, '');
      expect(response.polylinePoints, isEmpty);
    });

    test('Duration formatter formats hours and minutes correctly', () {
      const resp1 = RouteResponse(
        itineraryId: 1,
        dayId: 1,
        status: 'SUCCESS',
        routeType: 'ACTUAL_ROAD',
        mode: 'driving',
        directDistanceMeters: 0,
        totalDurationSeconds: 4500, // 75 mins -> 1 giờ 15 phút
      );
      expect(resp1.formattedDuration, '1 giờ 15 phút');

      const resp2 = RouteResponse(
        itineraryId: 1,
        dayId: 1,
        status: 'SUCCESS',
        routeType: 'ACTUAL_ROAD',
        mode: 'driving',
        directDistanceMeters: 0,
        totalDurationSeconds: 7200, // 2 hours -> 2 giờ
      );
      expect(resp2.formattedDuration, '2 giờ');

      const resp3 = RouteResponse(
        itineraryId: 1,
        dayId: 1,
        status: 'SUCCESS',
        routeType: 'ACTUAL_ROAD',
        mode: 'driving',
        directDistanceMeters: 0,
        totalDurationSeconds: 20, // < 1 min -> < 1 phút
      );
      expect(resp3.formattedDuration, '< 1 phút');
    });
  });

  group('Phase 6 - NavigationLauncherHelper Deep Links Tests', () {
    test('buildGoogleMapsUri returns null for empty waypoints', () {
      final uri = NavigationLauncherHelper.buildGoogleMapsUri(waypoints: []);
      expect(uri, isNull);
    });

    test('buildGoogleMapsUri builds search query for single stop', () {
      final uri = NavigationLauncherHelper.buildGoogleMapsUri(
        waypoints: const [LatLng(11.9431, 108.4382)],
      );

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '11.9431,108.4382');
    });

    test('buildGoogleMapsUri builds directions for two stops', () {
      final uri = NavigationLauncherHelper.buildGoogleMapsUri(
        waypoints: const [
          LatLng(11.9431, 108.4382),
          LatLng(11.9404, 108.4385),
        ],
        mode: 'driving',
      );

      expect(uri, isNotNull);
      expect(uri!.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['origin'], '11.9431,108.4382');
      expect(uri.queryParameters['destination'], '11.9404,108.4385');
      expect(uri.queryParameters['travelmode'], 'driving');
      expect(uri.queryParameters.containsKey('waypoints'), isFalse);
    });

    test('buildGoogleMapsUri builds directions with intermediate waypoints and maps travelmode', () {
      final uri = NavigationLauncherHelper.buildGoogleMapsUri(
        waypoints: const [
          LatLng(11.9431, 108.4382), // Origin
          LatLng(11.9410, 108.4383), // Intermediate 1
          LatLng(11.9420, 108.4384), // Intermediate 2
          LatLng(11.9404, 108.4385), // Destination
        ],
        mode: 'walking',
      );

      expect(uri, isNotNull);
      expect(uri!.queryParameters['origin'], '11.9431,108.4382');
      expect(uri.queryParameters['destination'], '11.9404,108.4385');
      expect(uri.queryParameters['travelmode'], 'walking');
      expect(uri.queryParameters['waypoints'], '11.941,108.4383|11.942,108.4384');
    });

    test('buildGoogleMapsUri maps cycling mode to bicycling', () {
      final uri = NavigationLauncherHelper.buildGoogleMapsUri(
        waypoints: const [
          LatLng(11.9431, 108.4382),
          LatLng(11.9404, 108.4385),
        ],
        mode: 'cycling',
      );

      expect(uri!.queryParameters['travelmode'], 'bicycling');
    });

    test('buildGoogleMapsUri caps intermediate waypoints at 9 stops', () {
      final List<LatLng> waypoints = [
        const LatLng(10.0, 100.0), // Origin
        for (int i = 1; i <= 15; i++) LatLng(10.0 + i * 0.01, 100.0 + i * 0.01),
        const LatLng(20.0, 110.0), // Destination
      ];

      final uri = NavigationLauncherHelper.buildGoogleMapsUri(waypoints: waypoints);
      expect(uri, isNotNull);
      final intermediateSegments = uri!.queryParameters['waypoints']!.split('|');
      expect(intermediateSegments.length, 9);
    });

    testWidgets('launchNavigation calls launcher with externalApplication mode', (tester) async {
      Uri? capturedUri;
      LaunchMode? capturedMode;

      Future<bool> fakeLauncher(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        capturedUri = uri;
        capturedMode = mode;
        return true;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NavigationLauncherHelper.launchNavigation(
                    context: context,
                    waypoints: const [
                      LatLng(11.9431, 108.4382),
                      LatLng(11.9404, 108.4385),
                    ],
                    mode: 'driving',
                    launcher: fakeLauncher,
                  );
                },
                child: const Text('Launch Nav'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Nav'));
      await tester.pumpAndSettle();

      expect(capturedUri, isNotNull);
      expect(capturedUri!.host, 'www.google.com');
      expect(capturedMode, LaunchMode.externalApplication);
    });

    testWidgets('launchNavigation warns transparently when intermediate waypoints exceed 9', (tester) async {
      Future<bool> fakeLauncher(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        return true;
      }

      final List<LatLng> waypoints = [
        const LatLng(10.0, 100.0), // Origin
        for (int i = 1; i <= 10; i++) LatLng(10.0 + i * 0.01, 100.0 + i * 0.01), // 10 intermediate
        const LatLng(20.0, 110.0), // Destination
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NavigationLauncherHelper.launchNavigation(
                    context: context,
                    waypoints: waypoints,
                    mode: 'driving',
                    launcher: fakeLauncher,
                  );
                },
                child: const Text('Launch Many Stops'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Many Stops'));
      await tester.pumpAndSettle();

      expect(
        find.text('Google Maps giới hạn tối đa 9 điểm trung gian. Đã chọn 11 điểm đầu tiên.'),
        findsOneWidget,
      );
    });
  });

  group('Phase 6 - RouteRepository Tests', () {
    test('getDayRoute makes authenticated GET request and returns RouteResponse', () async {
      String? requestedUrl;
      String? authHeader;

      final mockClient = MockClient((request) async {
        requestedUrl = request.url.toString();
        authHeader = request.headers['Authorization'];

        final responseBody = {
          'itineraryId': 10,
          'dayId': 101,
          'status': 'SUCCESS',
          'routeType': 'ACTUAL_ROAD',
          'mode': 'driving-car',
          'totalDistanceMeters': 2500.0,
          'directDistanceMeters': 2000.0,
          'totalDurationSeconds': 300.0,
          'geometryCoordinates': [
            [108.4382, 11.9431],
            [108.4385, 11.9404],
          ],
          'waypoints': [],
        };

        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = RouteRepository(apiClient: apiClient);

      final result = await repo.getDayRoute(
        itineraryId: 10,
        dayId: 101,
        mode: 'driving-car',
        token: 'test_token_abc',
      );

      expect(requestedUrl, contains('/api/itineraries/10/days/101/route?mode=driving-car'));
      expect(authHeader, 'Bearer test_token_abc');
      expect(result.status, 'SUCCESS');
      expect(result.routeType, 'ACTUAL_ROAD');
      expect(result.totalDistanceMeters, 2500.0);
    });

    test('getDayRoute throws exception on HTTP 400', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Day does not belong to itinerary'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final repo = RouteRepository(apiClient: apiClient);

      expect(
        () => repo.getDayRoute(itineraryId: 10, dayId: 999),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Phase 6 - ItineraryMapScreen Route Widget Tests', () {
    testWidgets('Renders ACTUAL_ROAD route info card with distance, duration, and Chỉ đường button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        final responseBody = {
          'itineraryId': 10,
          'dayId': 101,
          'status': 'SUCCESS',
          'routeType': 'ACTUAL_ROAD',
          'mode': 'driving',
          'totalDistanceMeters': 3500.0,
          'totalDurationSeconds': 420.0,
          'directDistanceMeters': 2800.0,
          'geometryCoordinates': [
            [108.4382, 11.9431],
            [108.4385, 11.9404],
          ],
          'waypoints': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final apiClient = ApiClient(client: mockClient);
      final routeRepo = RouteRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
            routeRepository: routeRepo,
          ),
        ),
      );

      // Initial pump kicks off the async route request
      await tester.pump();
      await tester.pumpAndSettle();

      // Road distance and duration must be displayed
      expect(find.textContaining('Khoảng cách đường bộ: 3.5 km'), findsOneWidget);
      expect(find.textContaining('Thời gian di chuyển: 7 phút'), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);

      // Verify solid blue polyline is rendered for ACTUAL_ROAD
      final polylineLayerFinder = find.byType(PolylineLayer);
      expect(polylineLayerFinder, findsOneWidget);
      final polylineLayer = tester.widget<PolylineLayer>(polylineLayerFinder);
      expect(polylineLayer.polylines.length, 1);
      expect(polylineLayer.polylines.first.color, const Color(0xFF2563EB));
    });

    testWidgets('Renders ESTIMATED_INDICATIVE fallback banner without fake duration and without polyline', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        final responseBody = {
          'itineraryId': 10,
          'dayId': 101,
          'status': 'FALLBACK',
          'routeType': 'ESTIMATED_INDICATIVE',
          'mode': 'driving',
          'totalDistanceMeters': null,
          'totalDurationSeconds': null,
          'directDistanceMeters': 1200.0,
          'geometryCoordinates': [],
          'waypoints': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final apiClient = ApiClient(client: mockClient);
      final routeRepo = RouteRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
            routeRepository: routeRepo,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Indicative straight-line distance must be displayed with warning
      expect(find.textContaining('Khoảng cách đường chim bay (ước tính): 1.2 km'), findsOneWidget);
      expect(find.text('Tuyến đường bộ tạm thời không khả dụng'), findsOneWidget);
      // Duration MUST NOT be displayed
      expect(find.textContaining('Thời gian di chuyển:'), findsNothing);
      expect(find.text('Chỉ đường'), findsOneWidget);

      // Verify NO route polylines are rendered for Haversine fallback
      final polylineLayerFinder = find.byType(PolylineLayer);
      if (polylineLayerFinder.evaluate().isNotEmpty) {
        final polylineLayer = tester.widget<PolylineLayer>(polylineLayerFinder);
        expect(polylineLayer.polylines, isEmpty, reason: 'Haversine fallback must not draw any route polyline');
      }
    });

    testWidgets('Renders single stop badge and Mở Google Maps button without misleading zero distance', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 2, // Day 2 has only 1 stop
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 điểm dừng có tọa độ'), findsOneWidget);
      expect(find.text('Mở Google Maps'), findsOneWidget);
      expect(find.textContaining('0.0'), findsNothing);
      expect(find.textContaining('0 m'), findsNothing);
    });

    testWidgets('Tapping Chỉ đường launches native navigation intent with waypoints', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Uri? launchedUri;
      Future<bool> fakeLauncher(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        return true;
      }

      final mockClient = MockClient((request) async {
        final responseBody = {
          'itineraryId': 10,
          'dayId': 101,
          'status': 'SUCCESS',
          'routeType': 'ACTUAL_ROAD',
          'mode': 'driving',
          'totalDistanceMeters': 3000.0,
          'totalDurationSeconds': 300.0,
          'directDistanceMeters': 2000.0,
          'geometryCoordinates': [
            [108.4382, 11.9431],
            [108.4385, 11.9404],
          ],
          'waypoints': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final apiClient = ApiClient(client: mockClient);
      final routeRepo = RouteRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
            routeRepository: routeRepo,
            navigationLauncher: fakeLauncher,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Tap 'Chỉ đường'
      await tester.tap(find.text('Chỉ đường'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri!.host, 'www.google.com');
      expect(launchedUri!.path, '/maps/dir/');
      expect(launchedUri!.queryParameters['origin'], '11.9431,108.4382');
      expect(launchedUri!.queryParameters['destination'], '11.9404,108.4385');
    });

    testWidgets('Switching travel mode requests new route with updated mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<String> requestedModes = [];

      final mockClient = MockClient((request) async {
        final mode = request.url.queryParameters['mode'] ?? '';
        requestedModes.add(mode);

        final responseBody = {
          'itineraryId': 10,
          'dayId': 101,
          'status': 'SUCCESS',
          'routeType': 'ACTUAL_ROAD',
          'mode': mode,
          'totalDistanceMeters': 3200.0,
          'totalDurationSeconds': 400.0,
          'directDistanceMeters': 2500.0,
          'geometryCoordinates': [
            [108.4382, 11.9431],
            [108.4385, 11.9404],
          ],
          'waypoints': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final apiClient = ApiClient(client: mockClient);
      final routeRepo = RouteRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
            routeRepository: routeRepo,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(requestedModes, contains('driving'));

      // Tap walking mode icon button
      await tester.tap(find.byTooltip('Đi bộ'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(requestedModes, contains('walking'));
    });

    testWidgets('Switching day chips clears previous route and fetches new day route', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<String> requestedPaths = [];

      final mockClient = MockClient((request) async {
        requestedPaths.add(request.url.path);

        final responseBody = {
          'itineraryId': 10,
          'dayId': 101,
          'status': 'SUCCESS',
          'routeType': 'ACTUAL_ROAD',
          'mode': 'driving',
          'totalDistanceMeters': 3000.0,
          'totalDurationSeconds': 300.0,
          'directDistanceMeters': 2000.0,
          'geometryCoordinates': [
            [108.4382, 11.9431],
            [108.4385, 11.9404],
          ],
          'waypoints': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final apiClient = ApiClient(client: mockClient);
      final routeRepo = RouteRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryMapScreen(
            itinerary: testItinerary,
            initialDayNumber: 1,
            routeRepository: routeRepo,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Khoảng cách đường bộ: 3.0 km'), findsOneWidget);

      // Tap 'Ngày 2'
      await tester.tap(find.text('Ngày 2 (1)'));
      await tester.pumpAndSettle();

      // Day 2 has only 1 stop -> should show 1 stop badge and clear the Day 1 road distance card
      expect(find.text('1 điểm dừng có tọa độ'), findsOneWidget);
      expect(find.textContaining('Khoảng cách đường bộ'), findsNothing);
    });
  });
}
