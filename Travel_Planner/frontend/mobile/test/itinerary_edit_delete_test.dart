import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/update_itinerary_request.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/edit_itinerary_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/my_itineraries_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/delete_itinerary_dialog.dart';

class MockAuthNotifier extends AuthNotifier {
  final Map<String, dynamic>? _user;
  final String? _token;

  MockAuthNotifier({
    Map<String, dynamic>? user,
    String? token,
    Map<String, dynamic>? mockUser,
    String? mockToken,
  }) : _user = user ?? mockUser,
       _token = token ?? mockToken;

  @override
  Map<String, dynamic>? get currentUser => _user;

  @override
  String? get token => _token;

  @override
  bool get isAuthenticated => _token != null;
}

class FakeItineraryDetailNotifier extends ItineraryDetailNotifier {
  final ItineraryDetail? _detail;

  FakeItineraryDetailNotifier({
    required super.itineraryId,
    ItineraryDetail? presetDetail,
    ItineraryDetail? detail,
  }) : _detail = presetDetail ?? detail;

  @override
  Future<void> loadDetail({String? token}) async {
    itineraryDetail = _detail;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}

void main() {
  group('UpdateItineraryRequest Serialization Tests', () {
    test('serializes required and optional fields correctly', () {
      const request = UpdateItineraryRequest(
        title: 'Khám phá Đà Nẵng 3N2Đ',
        description: 'Chuyến đi nghỉ mát',
        location: 'Đà Nẵng',
        coverImage: 'https://example.com/danang.jpg',
        budget: 5000000.0,
        theme: 'Nghỉ dưỡng',
        visibility: 'PUBLIC',
      );

      final json = request.toJson();

      expect(json['title'], equals('Khám phá Đà Nẵng 3N2Đ'));
      expect(json['description'], equals('Chuyến đi nghỉ mát'));
      expect(json['location'], equals('Đà Nẵng'));
      expect(json['coverImage'], equals('https://example.com/danang.jpg'));
      expect(json['budget'], equals(5000000.0));
      expect(json['theme'], equals('Nghỉ dưỡng'));
      expect(json['visibility'], equals('PUBLIC'));
    });

    test(
      'omits null or blank optional fields and defaults visibility to PRIVATE',
      () {
        const request = UpdateItineraryRequest(
          title: 'Khám phá Sa Pa',
          location: 'Sa Pa, Lào Cai',
          budget: 3500000.0,
          description: '   ',
          coverImage: '',
          theme: null,
        );

        final json = request.toJson();

        expect(json['title'], equals('Khám phá Sa Pa'));
        expect(json['location'], equals('Sa Pa, Lào Cai'));
        expect(json['budget'], equals(3500000.0));
        expect(json['visibility'], equals('PRIVATE'));
        expect(json['description'], isNull);
        expect(json['coverImage'], isNull);
        expect(json['theme'], isNull);
      },
    );
  });

  group('ItineraryCrudRepository Update and Delete Tests', () {
    test(
      'updateItinerary sends PUT to /api/itineraries/{id} with token and body',
      () async {
        String? requestedMethod;
        String? requestedUrl;
        String? authHeader;
        Map<String, dynamic>? sentBody;

        final mockClient = MockClient((request) async {
          requestedMethod = request.method;
          requestedUrl = request.url.toString();
          authHeader = request.headers['authorization'];
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;

          final responseData = {
            'itineraryId': 42,
            'title': 'Đà Lạt Mộng Mơ Đã Sửa',
            'location': 'Đà Lạt, Lâm Đồng',
            'totalDays': 3,
            'budget': 3200000.0,
            'visibility': 'PUBLIC',
            'status': 'ACTIVE',
            'days': [],
          };

          return http.Response(
            jsonEncode(responseData),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        const updateReq = UpdateItineraryRequest(
          title: 'Đà Lạt Mộng Mơ Đã Sửa',
          location: 'Đà Lạt, Lâm Đồng',
          budget: 3200000.0,
          visibility: 'PUBLIC',
        );

        final result = await repo.updateItinerary(
          42,
          updateReq,
          token: 'jwt-auth-token',
        );

        expect(requestedMethod, equals('PUT'));
        expect(requestedUrl, contains('/api/itineraries/42'));
        expect(authHeader, equals('Bearer jwt-auth-token'));
        expect(sentBody?['title'], equals('Đà Lạt Mộng Mơ Đã Sửa'));
        expect(result.itineraryId, equals(42));
        expect(result.title, equals('Đà Lạt Mộng Mơ Đã Sửa'));
      },
    );

    test('updateItinerary propagates ApiException on error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Bạn không có quyền chỉnh sửa lịch trình này',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      const updateReq = UpdateItineraryRequest(
        title: 'Test',
        location: 'Location',
        budget: 1000.0,
      );

      expect(
        () => repo.updateItinerary(42, updateReq, token: 'token'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test(
      'deleteItinerary sends DELETE to /api/itineraries/{id} with token',
      () async {
        String? requestedMethod;
        String? requestedUrl;
        String? authHeader;

        final mockClient = MockClient((request) async {
          requestedMethod = request.method;
          requestedUrl = request.url.toString();
          authHeader = request.headers['authorization'];

          return http.Response(
            jsonEncode({'message': 'Đã xóa lịch trình thành công'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        await repo.deleteItinerary(42, token: 'jwt-auth-token');

        expect(requestedMethod, equals('DELETE'));
        expect(requestedUrl, contains('/api/itineraries/42'));
        expect(authHeader, equals('Bearer jwt-auth-token'));
      },
    );

    test('deleteItinerary propagates ApiException on 404 not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Không tìm thấy lịch trình'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      expect(
        () => repo.deleteItinerary(999, token: 'token'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('EditItineraryScreen Widget Tests', () {
    testWidgets('prefills initial values into form fields', (tester) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      await tester.pumpWidget(
        MaterialApp(
          home: EditItineraryScreen(
            itineraryId: 10,
            initialTitle: 'Hà Giang Mùa Hoa Tam Giác Mạch',
            initialLocation: 'Hà Giang',
            initialBudget: 4000000,
            initialDescription: 'Chuyến đi ngắm hoa',
            initialCoverImage: 'https://example.com/hagiang.jpg',
            initialTheme: 'Khám phá',
            initialVisibility: 'PUBLIC',
            totalDays: 4,
            authNotifier: authNotifier,
          ),
        ),
      );

      expect(find.text('Chỉnh sửa lịch trình'), findsOneWidget);
      expect(find.text('Hà Giang Mùa Hoa Tam Giác Mạch'), findsOneWidget);
      expect(find.text('Hà Giang'), findsOneWidget);
      expect(find.text('4000000'), findsOneWidget);
      expect(find.text('Chuyến đi ngắm hoa'), findsOneWidget);
      expect(find.text('https://example.com/hagiang.jpg'), findsOneWidget);
      expect(find.text('Khám phá'), findsWidgets);
      expect(
        find.text(
          'Thời gian: 4 ngày. Lịch trình theo ngày và các hoạt động được quản lý riêng.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows validation errors when clearing required fields', (
      tester,
    ) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      await tester.pumpWidget(
        MaterialApp(
          home: EditItineraryScreen(
            itineraryId: 10,
            initialTitle: 'Tiêu đề cũ',
            initialLocation: 'Địa điểm cũ',
            initialBudget: 1000000,
            authNotifier: authNotifier,
          ),
        ),
      );

      // Clear title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tiêu đề cũ'),
        '',
      );
      // Clear location
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa điểm cũ'),
        '',
      );

      // Scroll down to submit button
      final saveBtn = find.text('Lưu thay đổi');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tiêu đề không được để trống'), findsOneWidget);
      expect(find.text('Điểm đến không được để trống'), findsOneWidget);
    });

    testWidgets('submits updated values and pops result on success', (
      tester,
    ) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'itineraryId': 10,
            'title': 'Hà Giang Cập Nhật',
            'location': 'Hà Giang Mới',
            'totalDays': 4,
            'budget': 4500000.0,
            'visibility': 'PRIVATE',
            'status': 'ACTIVE',
            'days': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      ItineraryDetail? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await Navigator.of(context)
                      .push<ItineraryDetail>(
                        MaterialPageRoute(
                          builder: (_) => EditItineraryScreen(
                            itineraryId: 10,
                            initialTitle: 'Hà Giang Cũ',
                            initialLocation: 'Hà Giang',
                            initialBudget: 4000000,
                            authNotifier: authNotifier,
                            repository: repo,
                          ),
                        ),
                      );
                },
                child: const Text('Mở màn hình sửa'),
              ),
            ),
          ),
        ),
      );

      // Open screen
      await tester.tap(find.text('Mở màn hình sửa'));
      await tester.pumpAndSettle();

      // Enter new title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hà Giang Cũ'),
        'Hà Giang Cập Nhật',
      );

      final saveBtn = find.text('Lưu thay đổi');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Cập nhật lịch trình thành công!'), findsOneWidget);
      expect(returnedResult, isNotNull);
      expect(returnedResult!.title, equals('Hà Giang Cập Nhật'));
    });

    testWidgets('displays error SnackBar when update API fails', (
      tester,
    ) async {
      final authNotifier = MockAuthNotifier(mockToken: 'valid-token');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Lỗi cập nhật từ máy chủ'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditItineraryScreen(
            itineraryId: 10,
            initialTitle: 'Hà Giang',
            initialLocation: 'Hà Giang',
            initialBudget: 4000000,
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );

      final saveBtn = find.text('Lưu thay đổi');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Lỗi cập nhật từ máy chủ'), findsOneWidget);
      expect(find.text('Chỉnh sửa lịch trình'), findsOneWidget);
    });
  });

  group('Delete Itinerary Confirmation Dialog Tests', () {
    testWidgets('shows confirmation dialog and cancels when tapping Hủy', (
      tester,
    ) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showDeleteItineraryConfirmationDialog(
                  context,
                  itineraryTitle: 'Đà Lạt 3N2Đ',
                );
              },
              child: const Text('Mở hộp thoại xóa'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở hộp thoại xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa lịch trình'), findsOneWidget);
      expect(find.textContaining('Đà Lạt 3N2Đ'), findsOneWidget);
      expect(
        find.textContaining('gỡ bỏ khỏi danh sách lịch trình hoạt động'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(dialogResult, equals(false));
      expect(find.text('Xác nhận xóa lịch trình'), findsNothing);
    });

    testWidgets('confirms deletion when tapping Xóa lịch trình', (
      tester,
    ) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showDeleteItineraryConfirmationDialog(
                  context,
                  itineraryTitle: 'Đà Lạt 3N2Đ',
                );
              },
              child: const Text('Mở hộp thoại xóa'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở hộp thoại xóa'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Xóa lịch trình'));
      await tester.pumpAndSettle();

      expect(dialogResult, equals(true));
      expect(find.text('Xác nhận xóa lịch trình'), findsNothing);
    });
  });

  group('ItineraryDetailScreen Edit and Delete Ownership Tests', () {
    final sampleDetail = ItineraryDetail(
      itineraryId: 77,
      title: 'Khám phá Phú Quốc',
      location: 'Phú Quốc',
      totalDays: 3,
      budget: 6000000,
      viewCount: 10,
      favoriteCount: 2,
      ratingCount: 1,
      averageRating: 5.0,
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      creator: const CreatorSummary(
        userId: 1,
        username: 'john_traveler',
        fullName: 'John Traveler',
      ),
      days: const [
        ItineraryDayDetail(
          dayId: 1,
          dayNumber: 1,
          title: 'Ngày 1: Check-in',
          activities: [],
        ),
      ],
    );

    testWidgets('shows Edit and Delete buttons when user is the owner', (
      tester,
    ) async {
      final ownerAuth = MockAuthNotifier(
        mockToken: 'owner-jwt',
        mockUser: {'username': 'john_traveler'},
      );

      final notifier = FakeItineraryDetailNotifier(
        itineraryId: 77,
        presetDetail: sampleDetail,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 77,
            authNotifier: ownerAuth,
            notifier: notifier,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('hides Edit and Delete buttons when user is NOT the owner', (
      tester,
    ) async {
      final otherAuth = MockAuthNotifier(
        mockToken: 'other-jwt',
        mockUser: {'username': 'another_user'},
      );

      final notifier = FakeItineraryDetailNotifier(
        itineraryId: 77,
        presetDetail: sampleDetail,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 77,
            authNotifier: otherAuth,
            notifier: notifier,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets(
      'deletes itinerary from detail screen and pops true on success',
      (tester) async {
        final ownerAuth = MockAuthNotifier(
          mockToken: 'owner-jwt',
          mockUser: {'username': 'john_traveler'},
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 77,
          presetDetail: sampleDetail,
        );

        bool deleteEndpointCalled = false;
        final mockClient = MockClient((request) async {
          if (request.method == 'DELETE' &&
              request.url.path.contains('/api/itineraries/77')) {
            deleteEndpointCalled = true;
            return http.Response(
              jsonEncode({'message': 'Đã xóa thành công'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );

        dynamic returnedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await Navigator.of(context).push<dynamic>(
                    MaterialPageRoute(
                      builder: (_) => ItineraryDetailScreen(
                        itineraryId: 77,
                        authNotifier: ownerAuth,
                        notifier: notifier,
                        crudRepository: repo,
                      ),
                    ),
                  );
                },
                child: const Text('Xem chi tiết'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Xem chi tiết'));
        await tester.pumpAndSettle();

        // Tap Delete icon
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Confirm in dialog
        await tester.tap(find.widgetWithText(FilledButton, 'Xóa lịch trình'));
        await tester.pumpAndSettle();

        expect(deleteEndpointCalled, isTrue);
        expect(returnedResult, equals(true));
        expect(find.text('Xem chi tiết'), findsOneWidget);
      },
    );
  });

  group('MyItinerariesScreen Edit and Delete Integration Tests', () {
    testWidgets('deletes itinerary via card popup menu and refreshes list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authNotifier = MockAuthNotifier(
        mockToken: 'token',
        mockUser: {'username': 'owner_user'},
      );

      int getCount = 0;
      bool deleteCalled = false;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          getCount++;
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'itineraryId': 55,
                  'title': 'Chuyến đi Vũng Tàu',
                  'location': 'Vũng Tàu',
                  'totalDays': 2,
                  'budget': 1500000.0,
                  'visibility': 'PUBLIC',
                  'viewCount': 0,
                  'favoriteCount': 0,
                  'ratingCount': 0,
                  'averageRating': 0.0,
                },
              ],
              'pageNumber': 0,
              'pageSize': 10,
              'totalElements': 1,
              'totalPages': 1,
              'isLast': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'DELETE') {
          deleteCalled = true;
          return http.Response(
            jsonEncode({'message': 'Đã xóa thành công'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MyItinerariesScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chuyến đi Vũng Tàu'), findsOneWidget);

      // Open 3-dots popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa'), findsOneWidget);
      expect(find.text('Xóa lịch trình'), findsOneWidget);

      // Tap Xóa lịch trình
      await tester.tap(find.text('Xóa lịch trình'));
      await tester.pumpAndSettle();

      // Confirmation dialog shows
      expect(find.text('Xác nhận xóa lịch trình'), findsOneWidget);

      // Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa lịch trình'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(find.text('Đã xóa lịch trình thành công.'), findsOneWidget);
      expect(getCount, greaterThanOrEqualTo(2));
    });
  });
}
