import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/administrative_areas/data/administrative_area_repository.dart';
import 'package:travel_planner_web/features/administrative_areas/domain/vietnam_region_mapping.dart';
import 'package:travel_planner_web/features/administrative_areas/presentation/screens/admin_administrative_areas_screen.dart';
import 'package:travel_planner_web/features/auth/data/auth_repository.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/locations/data/place_repository.dart';
import 'package:travel_planner_web/features/locations/presentation/screens/admin_places_screen.dart';

String _createMockJwt({required int expSeconds, String role = 'ADMIN'}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': 'admin_root', 'role': role, 'exp': expSeconds}),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

Future<AuthNotifier> _buildNotifier(
  MockClient mockClient, {
  String role = 'ADMIN',
}) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'jwt'});
  final storage = AuthStorage();
  final token = _createMockJwt(
    expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    role: role,
  );
  await storage.saveToken(token);
  await storage.saveUser({'userId': 1, 'username': 'admin_root', 'role': role});
  final notifier = AuthNotifier(
    storage: storage,
    repository: AuthRepository(apiClient: ApiClient(client: mockClient)),
  );
  await notifier.checkAuthStatus();
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  group('Phase 4 Administrative Areas (IDs 5.6 - 5.9)', () {
    testWidgets(
      'ID 5.6 & 5.7: Loads dynamic province/child hierarchy, stats, and handles error+retry',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool failStatsOnce = true;

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response(
              jsonEncode({
                'userId': 1,
                'username': 'admin_root',
                'role': 'ADMIN',
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/administrative-area/stats') {
            if (failStatsOnce) {
              failStatsOnce = false;
              return http.Response(
                jsonEncode({'message': 'Stats unavailable'}),
                500,
                headers: jsonHeaders,
              );
            }
            return http.Response(
              jsonEncode({
                'totalPlaces': 120,
                'linkedPlaces': 90,
                'unlinkedPlaces': 30,
                'coveragePercentage': 75.0,
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/provinces') {
            return http.Response(
              jsonEncode([
                {
                  'areaId': 1,
                  'code': '01',
                  'name': 'Thành phố Hà Nội',
                  'normalizedName': 'ha noi',
                  'areaType': 'PROVINCE',
                  'status': 'ACTIVE',
                },
                {
                  'areaId': 2,
                  'code': '79',
                  'name': 'Thành phố Hồ Chí Minh',
                  'normalizedName': 'ho chi minh',
                  'areaType': 'PROVINCE',
                  'status': 'ACTIVE',
                },
              ]),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/01/children') {
            return http.Response(
              jsonEncode([
                {
                  'areaId': 101,
                  'code': '00070',
                  'name': 'Phường Hoàn Kiếm',
                  'areaType': 'WARD',
                  'status': 'ACTIVE',
                  'parentCode': '01',
                  'parentName': 'Thành phố Hà Nội',
                },
              ]),
              200,
              headers: jsonHeaders,
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(client: mockClient);
        final authNotifier = await _buildNotifier(mockClient);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminAdministrativeAreasScreen(
              authNotifier: authNotifier,
              repository: AdministrativeAreaRepository(apiClient: apiClient),
              placeRepository: PlaceRepository(apiClient: apiClient),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial error + retry state for stats
        expect(
          find.textContaining('Không thể tải thống kê độ bao phủ'),
          findsOneWidget,
        );
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();

        // Verify stats KPIs
        expect(find.text('120'), findsOneWidget);
        expect(find.text('90'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
        expect(find.text('75.00%'), findsOneWidget);

        // Verify dynamic province count (2, NOT hardcoded 34)
        expect(find.text('Tổng số đơn vị: 2'), findsOneWidget);
        expect(find.text('Thành phố Hà Nội'), findsOneWidget);
        expect(find.text('Thành phố Hồ Chí Minh'), findsOneWidget);

        // Expand Hà Nội to dynamically fetch child communes/wards inline
        await tester.tap(find.text('Thành phố Hà Nội'));
        await tester.pumpAndSettle();
        expect(find.text('Phường Hoàn Kiếm'), findsOneWidget);
        expect(find.text('1 đơn vị trực thuộc'), findsOneWidget);
      },
    );

    testWidgets(
      'ID 5.8: Sequential Batch Resolve chunks by 50, respects dryRun, continues on error, and supports idempotent retry',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final List<List<int>> batchRequests = [];
        final List<bool> dryRunFlags = [];
        int activeConcurrentBatches = 0;
        int maxConcurrentBatches = 0;

        // 65 places -> must be chunked sequentially into [50, 15]
        final allPlacesPage0 = List.generate(
          50,
          (i) => {
            'placeId': i + 1,
            'name': 'Place ${i + 1}',
            'address': 'Hà Nội',
            'category': 'ATTRACTION',
            'status': 'ACTIVE',
          },
        );
        final allPlacesPage1 = List.generate(
          15,
          (i) => {
            'placeId': i + 51,
            'name': 'Place ${i + 51}',
            'address': 'Đà Nẵng',
            'category': 'ATTRACTION',
            'status': 'ACTIVE',
          },
        );

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response(
              jsonEncode({
                'userId': 1,
                'username': 'admin_root',
                'role': 'ADMIN',
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/administrative-area/stats') {
            return http.Response(
              jsonEncode({
                'totalPlaces': 65,
                'linkedPlaces': 0,
                'unlinkedPlaces': 65,
                'coveragePercentage': 0.0,
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/provinces') {
            return http.Response(jsonEncode([]), 200, headers: jsonHeaders);
          }
          if (request.url.path == '/api/admin/places') {
            final page =
                int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
            return http.Response(
              jsonEncode({
                'content': page == 0 ? allPlacesPage0 : allPlacesPage1,
                'totalElements': 65,
                'totalPages': 2,
                'pageNumber': page,
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/administrative-area/batch-resolve') {
            activeConcurrentBatches++;
            if (activeConcurrentBatches > maxConcurrentBatches) {
              maxConcurrentBatches = activeConcurrentBatches;
            }
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final ids = (body['placeIds'] as List)
                .map((e) => (e as num).toInt())
                .toList();
            batchRequests.add(ids);
            dryRunFlags.add(body['dryRun'] == true);
            await Future<void>.delayed(const Duration(milliseconds: 5));
            activeConcurrentBatches--;

            // Simulate chunk 1 (50 items) server error on first run, while chunk 2 (15 items) succeeds!
            if (ids.length == 50 && batchRequests.length == 1) {
              return http.Response(
                jsonEncode({'message': 'Timeout chunk 1'}),
                500,
                headers: jsonHeaders,
              );
            }

            return http.Response(
              jsonEncode({
                'totalPlacesExamined': ids.length,
                'linkedCount': ids.length,
                'skippedCount': 0,
                'quarantinedCount': 0,
                'ambiguousCount': 0,
                'noMatchCount': 0,
                'dryRun': body['dryRun'] == true,
                'results': ids
                    .map(
                      (id) => {
                        'placeId': id,
                        'placeName': 'Place $id',
                        'placeAddress': 'Hà Nội',
                        'confidence': 'HIGH_CONFIDENCE',
                        'eligibleForAutoLink': true,
                        'currentlyLinked': body['dryRun'] != true,
                      },
                    )
                    .toList(),
              }),
              200,
              headers: jsonHeaders,
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(client: mockClient);
        final authNotifier = await _buildNotifier(mockClient);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminAdministrativeAreasScreen(
              authNotifier: authNotifier,
              repository: AdministrativeAreaRepository(apiClient: apiClient),
              placeRepository: PlaceRepository(apiClient: apiClient),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Batch Linking dialog from toolbar
        await tester.tap(find.text('Liên kết hàng loạt'));
        await tester.pumpAndSettle();

        // Dry Run switch visible by default inside dialog
        expect(find.text('Chạy thử'), findsOneWidget);

        await tester.tap(find.text('Chạy thử liên kết'));
        await tester.pumpAndSettle();

        // Verify sequential chunking (50 + 15) and non-parallel execution
        expect(maxConcurrentBatches, 1);
        expect(batchRequests.length, 2);
        expect(batchRequests[0].length, 50);
        expect(batchRequests[1].length, 15);
        expect(dryRunFlags, everyElement(isTrue));

        // Verify all 6 Vietnamese progress counters
        expect(find.text('Tổng số địa điểm'), findsWidgets);
        expect(find.text('Đã xử lý'), findsOneWidget);
        expect(find.text('Thành công'), findsOneWidget);
        expect(find.text('Thất bại'), findsOneWidget);
        expect(find.text('Bỏ qua'), findsOneWidget);
        expect(find.text('Chờ xử lý'), findsOneWidget);

        // Chunk 1 failed (50), Chunk 2 succeeded (15) -> Retry button appears for 50 failed items
        expect(find.text('Chạy lại địa điểm thất bại (50)'), findsOneWidget);

        // Retry failed items
        await tester.tap(find.text('Chạy lại địa điểm thất bại (50)'));
        await tester.pumpAndSettle();

        expect(batchRequests.length, 3);
        expect(batchRequests[2].length, 50);
        expect(find.text('Chạy lại địa điểm thất bại (50)'), findsNothing);
      },
    );

    testWidgets(
      'ID 5.9: Integrates PlaceAdministrativeAreaDialog into AdminPlacesScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        String? linkedCode;
        String? linkedAreaName;

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response(
              jsonEncode({
                'userId': 1,
                'username': 'admin_root',
                'role': 'ADMIN',
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/admin/places') {
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'placeId': 10,
                    'name': 'Hồ Hoàn Kiếm',
                    'address': 'Hoàn Kiếm, Hà Nội',
                    'category': 'ATTRACTION',
                    'status': 'ACTIVE',
                    'latitude': 21.0285,
                    'longitude': 105.8542,
                    if (linkedAreaName != null)
                      'administrativeArea': {
                        'areaId': 101,
                        'code': linkedCode,
                        'name': linkedAreaName,
                        'parentName': 'Thành phố Hà Nội',
                      },
                  },
                ],
                'totalElements': 1,
                'totalPages': 1,
                'pageNumber': 0,
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/10/administrative-area/preview') {
            return http.Response(
              jsonEncode({
                'placeId': 10,
                'placeName': 'Hồ Hoàn Kiếm',
                'placeAddress': 'Hoàn Kiếm, Hà Nội',
                'confidence': 'HIGH_CONFIDENCE',
                'eligibleForAutoLink': true,
                'currentlyLinked': false,
                'explanation': 'Khớp chính xác Phường Hoàn Kiếm',
                'resolvedArea': {
                  'areaId': 101,
                  'code': '00070',
                  'name': 'Phường Hoàn Kiếm',
                  'areaType': 'WARD',
                  'parentName': 'Thành phố Hà Nội',
                },
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/10/administrative-area/link') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            linkedCode = body['administrativeAreaCode']?.toString();
            linkedAreaName = 'Phường Hoàn Kiếm';
            return http.Response(
              jsonEncode({
                'placeId': 10,
                'name': 'Hồ Hoàn Kiếm',
                'address': 'Hoàn Kiếm, Hà Nội',
                'category': 'ATTRACTION',
                'status': 'ACTIVE',
                'administrativeArea': {
                  'areaId': 101,
                  'code': linkedCode,
                  'name': linkedAreaName,
                  'parentName': 'Thành phố Hà Nội',
                },
              }),
              200,
              headers: jsonHeaders,
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(client: mockClient);
        final authNotifier = await _buildNotifier(mockClient);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminPlacesScreen(
              authNotifier: authNotifier,
              repository: PlaceRepository(apiClient: apiClient),
              administrativeAreaRepository: AdministrativeAreaRepository(
                apiClient: apiClient,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap ĐVHC action button on row
        await tester.tap(find.text('ĐVHC').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Gán mã khu vực hành chính: Hồ Hoàn Kiếm'),
          findsOneWidget,
        );

        // Preview resolution
        await tester.tap(find.text('Xem trước phân giải tự động'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Phường Hoàn Kiếm (00070)'), findsOneWidget);

        // Save manual link
        await tester.tap(find.text('Lưu mã khu vực'));
        await tester.pumpAndSettle();

        expect(linkedCode, '00070');
        expect(find.text('Phường Hoàn Kiếm'), findsOneWidget);
      },
    );

    testWidgets(
      'Redesigned table supports search, child error retry, and overwrite mode toggle in dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool failChildrenOnce = true;

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response(
              jsonEncode({
                'userId': 1,
                'username': 'admin_root',
                'role': 'ADMIN',
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/administrative-area/stats') {
            return http.Response(
              jsonEncode({
                'totalPlaces': 10,
                'linkedPlaces': 8,
                'unlinkedPlaces': 2,
                'coveragePercentage': 80.0,
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/provinces') {
            return http.Response(
              jsonEncode([
                {
                  'areaId': 1,
                  'code': '01',
                  'name': 'Thành phố Hà Nội',
                  'areaType': 'PROVINCE',
                  'status': 'ACTIVE',
                },
                {
                  'areaId': 2,
                  'code': '79',
                  'name': 'Thành phố Hồ Chí Minh',
                  'areaType': 'PROVINCE',
                  'status': 'INACTIVE',
                },
              ]),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/01/children') {
            if (failChildrenOnce) {
              failChildrenOnce = false;
              return http.Response(
                jsonEncode({'message': 'Children error'}),
                500,
                headers: jsonHeaders,
              );
            }
            return http.Response(
              jsonEncode([
                {
                  'areaId': 101,
                  'code': '00070',
                  'name': 'Phường Hoàn Kiếm',
                  'areaType': 'WARD',
                  'status': 'ACTIVE',
                  'parentCode': '01',
                  'parentName': 'Thành phố Hà Nội',
                },
              ]),
              200,
              headers: jsonHeaders,
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(client: mockClient);
        final authNotifier = await _buildNotifier(mockClient);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminAdministrativeAreasScreen(
              authNotifier: authNotifier,
              repository: AdministrativeAreaRepository(apiClient: apiClient),
              placeRepository: PlaceRepository(apiClient: apiClient),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand Hà Nội -> triggers child error -> tap Thử lại -> loads Phường Hoàn Kiếm
        await tester.tap(find.text('Thành phố Hà Nội'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Không thể tải đơn vị trực thuộc'),
          findsOneWidget,
        );

        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        expect(find.text('Phường Hoàn Kiếm'), findsOneWidget);

        // Search by code 79
        await tester.enterText(find.byType(TextField).first, '79');
        await tester.pumpAndSettle();
        expect(find.text('Thành phố Hồ Chí Minh'), findsOneWidget);
        expect(find.text('Thành phố Hà Nội'), findsNothing);

        // Open Batch dialog -> toggle dryRun off and overwrite on
        await tester.tap(find.text('Liên kết hàng loạt'));
        await tester.pumpAndSettle();

        expect(find.text('Chạy thử liên kết'), findsOneWidget);
        await tester.tap(find.byType(Switch).at(0)); // disable dryRun
        await tester.tap(find.byType(Switch).at(1)); // enable overwrite
        await tester.pumpAndSettle();

        expect(find.text('Thực thi liên kết'), findsOneWidget);
        expect(
          find.textContaining('Cảnh báo: Khi tắt Chế độ chạy thử'),
          findsOneWidget,
        );
      },
    );

    test('Region mapping covers all 34 unique province codes and handles unknown codes safely', () {
      expect(kProvinceCodeToRegion.length, 34);
      final northCount = kProvinceCodeToRegion.values
          .where((r) => r == VietnamRegion.north)
          .length;
      final centralCount = kProvinceCodeToRegion.values
          .where((r) => r == VietnamRegion.central)
          .length;
      final southCount = kProvinceCodeToRegion.values
          .where((r) => r == VietnamRegion.south)
          .length;
      expect(northCount, 15);
      expect(centralCount, 11);
      expect(southCount, 8);
      expect(resolveProvinceRegion('99'), isNull);
      expect(matchesProvinceRegionFilter('99', VietnamRegion.all), isTrue);
      expect(matchesProvinceRegionFilter('99', VietnamRegion.north), isFalse);
    });

    testWidgets(
      'Removes Status column and supports search -> region filter -> pagination with child expansion isolation',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 15 North + 2 Central + 2 South = 19 provinces to exercise pagination (10/page)
        final northCodes = [
          '01',
          '04',
          '08',
          '11',
          '12',
          '14',
          '15',
          '19',
          '20',
          '22',
          '24',
          '25',
          '31',
          '33',
          '37',
        ];
        final provincesJson = [
          ...northCodes.map(
            (c) => {
              'areaId': int.parse(c),
              'code': c,
              'name': 'Tỉnh Bắc $c',
              'areaType': 'PROVINCE',
              'status': 'ACTIVE',
            },
          ),
          {
            'areaId': 48,
            'code': '48',
            'name': 'Thành phố Đà Nẵng',
            'areaType': 'CENTRAL_CITY',
            'status': 'ACTIVE',
          },
          {
            'areaId': 56,
            'code': '56',
            'name': 'Tỉnh Khánh Hoà',
            'areaType': 'PROVINCE',
            'status': 'ACTIVE',
          },
          {
            'areaId': 79,
            'code': '79',
            'name': 'Thành phố Hồ Chí Minh',
            'areaType': 'CENTRAL_CITY',
            'status': 'ACTIVE',
          },
          {
            'areaId': 92,
            'code': '92',
            'name': 'Thành phố Cần Thơ',
            'areaType': 'CENTRAL_CITY',
            'status': 'ACTIVE',
          },
        ];

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/me') {
            return http.Response(
              jsonEncode({
                'userId': 1,
                'username': 'admin_root',
                'role': 'ADMIN',
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path ==
              '/api/admin/places/administrative-area/stats') {
            return http.Response(
              jsonEncode({
                'totalPlaces': 19,
                'linkedPlaces': 10,
                'unlinkedPlaces': 9,
                'coveragePercentage': 52.63,
              }),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/provinces') {
            return http.Response(
              jsonEncode(provincesJson),
              200,
              headers: jsonHeaders,
            );
          }
          if (request.url.path == '/api/administrative-areas/01/children') {
            return http.Response(
              jsonEncode([
                {
                  'areaId': 101,
                  'code': '00070',
                  'name': 'Phường Hoàn Kiếm',
                  'areaType': 'WARD',
                  'status': 'ACTIVE',
                  'parentCode': '01',
                  'parentName': 'Tỉnh Bắc 01',
                },
              ]),
              200,
              headers: jsonHeaders,
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(client: mockClient);
        final authNotifier = await _buildNotifier(mockClient);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminAdministrativeAreasScreen(
              authNotifier: authNotifier,
              repository: AdministrativeAreaRepository(apiClient: apiClient),
              placeRepository: PlaceRepository(apiClient: apiClient),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Status column removed
        expect(find.text('Trạng thái'), findsNothing);

        // Initial pagination: 1-10 of 19
        expect(find.text('Hiển thị 1–10 trên 19 đơn vị'), findsOneWidget);
        expect(find.text('Tỉnh Bắc 01'), findsOneWidget);
        expect(find.text('Thành phố Cần Thơ'), findsNothing);

        // Expand province 01 on page 1 -> child appears
        await tester.tap(find.text('Tỉnh Bắc 01'));
        await tester.pumpAndSettle();
        expect(find.text('Phường Hoàn Kiếm'), findsOneWidget);

        // Go to page 2 -> expanded child from page 1 must not leak
        await tester.ensureVisible(find.text('Trang sau'));
        await tester.tap(find.text('Trang sau'));
        await tester.pumpAndSettle();
        expect(find.text('Hiển thị 11–19 trên 19 đơn vị'), findsOneWidget);
        expect(find.text('Phường Hoàn Kiếm'), findsNothing);
        expect(find.text('Thành phố Cần Thơ'), findsOneWidget);

        // Filter by Miền Bắc -> resets to page 1 (1-10 of 15)
        await tester.tap(find.text('Tất cả khu vực'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Miền Bắc').last);
        await tester.pumpAndSettle();
        expect(find.text('Hiển thị 1–10 trên 15 đơn vị'), findsOneWidget);
        expect(find.text('Thành phố Cần Thơ'), findsNothing);

        // Combine search + region filter (Miền Bắc + "31" -> 1 result)
        await tester.enterText(find.byType(TextField).first, '31');
        await tester.pumpAndSettle();
        expect(find.text('Hiển thị 1–1 trên 1 đơn vị'), findsOneWidget);
        expect(find.text('Tỉnh Bắc 31'), findsOneWidget);
      },
    );
  });
}
