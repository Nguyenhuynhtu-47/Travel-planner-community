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
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/create_activity_request.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/data/models/reorder_activity_item.dart';
import 'package:mobile/features/itinerary/data/models/update_activity_request.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_form_dialog.dart';
import 'package:mobile/features/itinerary/presentation/widgets/delete_activity_dialog.dart';
import 'package:mobile/features/itinerary/presentation/widgets/reorder_activities_dialog.dart';

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
  ItineraryDetail? _detail;

  FakeItineraryDetailNotifier({
    required super.itineraryId,
    ItineraryDetail? presetDetail,
    ItineraryDetail? detail,
  }) : _detail = presetDetail ?? detail;

  void updateDetail(ItineraryDetail newDetail) {
    _detail = newDetail;
    itineraryDetail = newDetail;
    notifyListeners();
  }

  @override
  Future<void> loadDetail({String? token}) async {
    itineraryDetail = _detail;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}

void main() {
  group(
    'CreateActivityRequest & UpdateActivityRequest Serialization Tests',
    () {
      test('CreateActivityRequest serializes all fields and formats times', () {
        final request = CreateActivityRequest(
          name: 'Ăn sáng bánh mì chảo',
          description: 'Quán Cô Năm',
          destinationId: 5,
          startTime: '07:30',
          endTime: '08:30:00',
          cost: 45000.0,
        );

        final json = request.toJson();

        expect(json['name'], equals('Ăn sáng bánh mì chảo'));
        expect(json['description'], equals('Quán Cô Năm'));
        expect(json['destinationId'], equals(5));
        expect(json['startTime'], equals('07:30:00'));
        expect(json['endTime'], equals('08:30:00'));
        expect(json['cost'], equals(45000.0));
      });

      test('CreateActivityRequest omits null or blank optional fields', () {
        final request = CreateActivityRequest(name: 'Dạo quanh bờ hồ');

        final json = request.toJson();

        expect(json['name'], equals('Dạo quanh bờ hồ'));
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('destinationId'), isFalse);
        expect(json.containsKey('startTime'), isFalse);
        expect(json.containsKey('endTime'), isFalse);
        expect(json.containsKey('cost'), isFalse);
      });

      test(
        'UpdateActivityRequest preserves null values for cleared fields',
        () {
          final request = UpdateActivityRequest(
            name: 'Tên hoạt động cập nhật',
            description: '',
            destinationId: null,
            startTime: null,
            endTime: null,
            cost: 0.0,
          );

          final json = request.toJson();

          expect(json['name'], equals('Tên hoạt động cập nhật'));
          expect(json['description'], isNull);
          expect(json['destinationId'], isNull);
          expect(json['startTime'], isNull);
          expect(json['endTime'], isNull);
          expect(json['cost'], equals(0.0));
        },
      );

      test('ReorderActivityItem serializes activityId and displayOrder', () {
        const item = ReorderActivityItem(activityId: 12, displayOrder: 2);
        final json = item.toJson();

        expect(json['activityId'], equals(12));
        expect(json['displayOrder'], equals(2));
      });
    },
  );

  group('ItineraryCrudRepository Activity CRUD Network Tests', () {
    test('addActivity sends POST to /api/itineraries/{id}/days/{dayId}/activities with Bearer token', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        if (request.method == 'POST' &&
            request.url.path == '/api/itineraries/10/days/20/activities') {
          return http.Response(
            jsonEncode({
              'activityId': 101,
              'name': 'Cà phê sáng',
              'description': 'View thung lũng',
              'startTime': '08:00:00',
              'endTime': '09:30:00',
              'cost': 60000.0,
              'displayOrder': 1,
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      final result = await repository.addActivity(
        10,
        20,
        const CreateActivityRequest(
          name: 'Cà phê sáng',
          description: 'View thung lũng',
          startTime: '08:00',
          endTime: '09:30',
          cost: 60000.0,
        ),
        token: 'test_token',
      );

      expect(capturedRequest.method, equals('POST'));
      expect(
        capturedRequest.url.path,
        equals('/api/itineraries/10/days/20/activities'),
      );
      expect(
        capturedRequest.headers['Authorization'],
        equals('Bearer test_token'),
      );
      expect(result.activityId, equals(101));
      expect(result.name, equals('Cà phê sáng'));
      expect(result.displayOrder, equals(1));
    });

    test('updateActivity sends PUT to /api/itineraries/{id}/days/{dayId}/activities/{activityId}', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        if (request.method == 'PUT' &&
            request.url.path == '/api/itineraries/10/days/20/activities/101') {
          return http.Response(
            jsonEncode({
              'activityId': 101,
              'name': 'Cà phê ngắm hoàng hôn',
              'description': 'Đổi giờ sang chiều',
              'startTime': '16:30:00',
              'endTime': '18:00:00',
              'cost': 80000.0,
              'displayOrder': 1,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      final result = await repository.updateActivity(
        10,
        20,
        101,
        const UpdateActivityRequest(
          name: 'Cà phê ngắm hoàng hôn',
          description: 'Đổi giờ sang chiều',
          startTime: '16:30',
          endTime: '18:00',
          cost: 80000.0,
        ),
        token: 'test_token',
      );

      expect(capturedRequest.method, equals('PUT'));
      expect(
        capturedRequest.url.path,
        equals('/api/itineraries/10/days/20/activities/101'),
      );
      expect(result.name, equals('Cà phê ngắm hoàng hôn'));
      expect(result.startTime, equals('16:30'));
    });

    test('deleteActivity sends DELETE to /api/itineraries/{id}/days/{dayId}/activities/{activityId}', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        if (request.method == 'DELETE' &&
            request.url.path == '/api/itineraries/10/days/20/activities/101') {
          return http.Response(
            jsonEncode({'message': 'Đã xóa hoạt động thành công'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      await repository.deleteActivity(10, 20, 101, token: 'test_token');

      expect(capturedRequest.method, equals('DELETE'));
      expect(
        capturedRequest.url.path,
        equals('/api/itineraries/10/days/20/activities/101'),
      );
    });

    test('reorderActivities sends PUT to /api/itineraries/{id}/days/{dayId}/activities/reorder with list', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        if (request.method == 'PUT' &&
            request.url.path ==
                '/api/itineraries/10/days/20/activities/reorder') {
          return http.Response(
            jsonEncode([
              {
                'activityId': 102,
                'name': 'Hoạt động 2 lên 1',
                'displayOrder': 1,
              },
              {
                'activityId': 101,
                'name': 'Hoạt động 1 xuống 2',
                'displayOrder': 2,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      final result = await repository.reorderActivities(10, 20, const [
        ReorderActivityItem(activityId: 102, displayOrder: 1),
        ReorderActivityItem(activityId: 101, displayOrder: 2),
      ], token: 'test_token');

      expect(capturedRequest.method, equals('PUT'));
      expect(
        capturedRequest.url.path,
        equals('/api/itineraries/10/days/20/activities/reorder'),
      );
      expect(result.length, equals(2));
      expect(result.first.activityId, equals(102));
      expect(result.first.displayOrder, equals(1));
    });

    test('reorderActivities propagates ApiException on failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Số lượng hoạt động sắp xếp không khớp'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );

      expect(
        () => repository.reorderActivities(10, 20, const [
          ReorderActivityItem(activityId: 101, displayOrder: 1),
        ], token: 'test_token'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Số lượng hoạt động sắp xếp không khớp'),
          ),
        ),
      );
    });
  });

  group('ActivityFormDialog Widget Tests', () {
    testWidgets('renders ActivityFormDialog for adding an activity', (
      tester,
    ) async {
      final mockClient = MockClient(
        (request) async => http.Response('{}', 200),
      );
      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'test_user'},
        token: 'token123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showActivityFormDialog(
                context,
                itineraryId: 10,
                dayId: 20,
                dayNumber: 2,
                dayTitle: 'Khám phá Sa Pa',
                authNotifier: authNotifier,
                repository: repository,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm hoạt động mới'), findsOneWidget);
      expect(find.text('Ngày 2 • Khám phá Sa Pa'), findsOneWidget);
      expect(find.text('Tên hoạt động *'), findsOneWidget);
      expect(find.text('Thời gian thực hiện'), findsOneWidget);
      expect(find.text('Chi phí ước tính (VNĐ)'), findsOneWidget);
      expect(find.text('Thêm hoạt động'), findsOneWidget);
    });

    testWidgets('validates required name field before submitting', (
      tester,
    ) async {
      final mockClient = MockClient(
        (request) async => http.Response('{}', 200),
      );
      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'test_user'},
        token: 'token123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showActivityFormDialog(
                context,
                itineraryId: 10,
                dayId: 20,
                dayNumber: 1,
                authNotifier: authNotifier,
                repository: repository,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap submit with empty name
      await tester.tap(find.text('Thêm hoạt động'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên hoạt động'), findsOneWidget);
    });

    testWidgets('submits add activity successfully and pops true', (
      tester,
    ) async {
      bool apiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/itineraries/10/days/20/activities') {
          apiCalled = true;
          return http.Response(
            jsonEncode({
              'activityId': 105,
              'name': 'Check-in Fansipan',
              'displayOrder': 1,
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'test_user'},
        token: 'token123',
      );

      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showActivityFormDialog(
                  context,
                  itineraryId: 10,
                  dayId: 20,
                  dayNumber: 1,
                  authNotifier: authNotifier,
                  repository: repository,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Check-in Fansipan',
      );
      await tester.pump();

      await tester.tap(find.text('Thêm hoạt động'));
      await tester.pumpAndSettle();

      expect(apiCalled, isTrue);
      expect(dialogResult, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('renders ActivityFormDialog for editing prefilled values', (
      tester,
    ) async {
      final mockClient = MockClient(
        (request) async => http.Response('{}', 200),
      );
      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'test_user'},
        token: 'token123',
      );

      const existingActivity = ActivityDetail(
        activityId: 101,
        name: 'Trekking Bản Cát Cát',
        description: 'Mang theo nước uống',
        startTime: '08:00',
        endTime: '11:30',
        estimatedCost: 150000.0,
        displayOrder: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showActivityFormDialog(
                context,
                itineraryId: 10,
                dayId: 20,
                dayNumber: 2,
                initialActivity: existingActivity,
                authNotifier: authNotifier,
                repository: repository,
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉnh sửa hoạt động'), findsOneWidget);
      expect(find.text('Trekking Bản Cát Cát'), findsOneWidget);
      expect(find.text('Mang theo nước uống'), findsOneWidget);
      expect(find.text('150000'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
    });

    testWidgets(
      'renders modal bottom sheet without overflowing on a small mobile screen (360x640)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'test_user'},
          token: 'token123',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showActivityFormDialog(
                  context,
                  itineraryId: 10,
                  dayId: 20,
                  dayNumber: 1,
                  authNotifier: authNotifier,
                  repository: repository,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Thêm hoạt động mới'), findsOneWidget);
        expect(find.byType(ActivityFormBottomSheet), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.text('Hủy'), findsOneWidget);
        expect(find.text('Thêm hoạt động'), findsOneWidget);
      },
    );

    testWidgets(
      'form fields and submit button remain usable when software keyboard opens',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'test_user'},
          token: 'token123',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showActivityFormDialog(
                  context,
                  itineraryId: 10,
                  dayId: 20,
                  dayNumber: 1,
                  authNotifier: authNotifier,
                  repository: repository,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Title and input remain accessible
        expect(find.text('Thêm hoạt động mới'), findsOneWidget);
        final nameField = find.widgetWithText(TextFormField, 'Tên hoạt động *');
        expect(nameField, findsOneWidget);

        await tester.enterText(nameField, 'Uống cà phê sáng');
        expect(find.text('Uống cà phê sáng'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping close icon dismisses modal bottom sheet returning null or false',
      (tester) async {
        bool? sheetResult;
        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'test_user'},
          token: 'token123',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  sheetResult = await showActivityFormDialog(
                    context,
                    itineraryId: 10,
                    dayId: 20,
                    dayNumber: 1,
                    authNotifier: authNotifier,
                    repository: repository,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(ActivityFormBottomSheet), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.byType(ActivityFormBottomSheet), findsNothing);
        expect(sheetResult, isFalse);
      },
    );

    testWidgets(
      'displays error SnackBar and stays on form when API submission fails',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Tên hoạt động không hợp lệ'}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'test_user'},
          token: 'token123',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showActivityFormDialog(
                    context,
                    itineraryId: 10,
                    dayId: 20,
                    dayNumber: 1,
                    authNotifier: authNotifier,
                    repository: repository,
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tên hoạt động *'),
          'Hoạt động lỗi',
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm hoạt động'));
        await tester.pumpAndSettle();

        // Sheet remains open
        expect(find.byType(ActivityFormBottomSheet), findsOneWidget);
        // Error message shown in SnackBar
        expect(find.text('Tên hoạt động không hợp lệ'), findsOneWidget);
      },
    );
  });

  group('DeleteActivityConfirmationDialog Tests', () {
    testWidgets('shows confirmation dialog and cancels when tapping Hủy', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDeleteActivityConfirmationDialog(
                  context,
                  activityName: 'Chèo thuyền Kayak',
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa hoạt động'), findsWidgets);
      expect(find.textContaining('Chèo thuyền Kayak'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('confirms deletion when tapping Xóa hoạt động', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDeleteActivityConfirmationDialog(
                  context,
                  activityName: 'Chèo thuyền Kayak',
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Find the elevated button that says Xóa hoạt động
      final deleteBtn = find.widgetWithText(ElevatedButton, 'Xóa hoạt động');
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

  group('ReorderActivitiesDialog Tests', () {
    testWidgets('renders list of activities and saves reordered list', (
      tester,
    ) async {
      bool reorderApiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path ==
                '/api/itineraries/10/days/20/activities/reorder') {
          reorderApiCalled = true;
          return http.Response(
            jsonEncode([
              {'activityId': 102, 'name': 'Hoạt động 2', 'displayOrder': 1},
              {'activityId': 101, 'name': 'Hoạt động 1', 'displayOrder': 2},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'test_user'},
        token: 'token123',
      );

      const activities = [
        ActivityDetail(activityId: 101, name: 'Hoạt động 1', displayOrder: 1),
        ActivityDetail(activityId: 102, name: 'Hoạt động 2', displayOrder: 2),
      ];

      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showReorderActivitiesDialog(
                  context,
                  itineraryId: 10,
                  dayId: 20,
                  dayNumber: 1,
                  activities: activities,
                  authNotifier: authNotifier,
                  repository: repository,
                );
              },
              child: const Text('Open Reorder Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Reorder Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Sắp xếp hoạt động'), findsOneWidget);
      expect(find.text('Hoạt động 1'), findsOneWidget);
      expect(find.text('Hoạt động 2'), findsOneWidget);

      await tester.tap(find.text('Lưu thứ tự'));
      await tester.pumpAndSettle();

      expect(reorderApiCalled, isTrue);
      expect(dialogResult, isTrue);
    });
  });

  group('ItineraryDetailScreen Activity Management Integration Tests', () {
    final testDetailWithOwner = ItineraryDetail(
      itineraryId: 10,
      title: 'Đà Lạt Mộng Mơ 3N2Đ',
      description: 'Chuyến đi nghỉ dưỡng',
      location: 'Đà Lạt',
      totalDays: 2,
      budget: 3000000.0,
      theme: 'Nghỉ dưỡng',
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      viewCount: 10,
      favoriteCount: 5,
      ratingCount: 3,
      averageRating: 4.8,
      createdAt: DateTime(2026, 10, 20),
      creator: const CreatorSummary(
        userId: 1,
        username: 'traveler_viet',
        fullName: 'Nguyễn Văn Việt',
      ),
      days: [
        ItineraryDayDetail(
          dayId: 21,
          dayNumber: 1,
          title: 'Ngày 1: Check-in & Cà phê',
          date: DateTime(2026, 10, 27),
          activities: [
            const ActivityDetail(
              activityId: 301,
              name: 'Uống cà phê Tùng',
              startTime: '08:00',
              endTime: '09:30',
              estimatedCost: 50000.0,
              displayOrder: 1,
            ),
            const ActivityDetail(
              activityId: 302,
              name: 'Dạo Quảng trường Lâm Viên',
              startTime: '10:00',
              endTime: '11:30',
              estimatedCost: 0.0,
              displayOrder: 2,
            ),
          ],
        ),
        ItineraryDayDetail(
          dayId: 22,
          dayNumber: 2,
          title: 'Ngày 2',
          date: DateTime(2026, 10, 28),
          activities: [],
        ),
      ],
    );

    testWidgets(
      'shows Add Activity, Reorder, and Activity popup menus when viewer is owner',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'traveler_viet'},
          token: 'token_viet',
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 10,
          presetDetail: testDetailWithOwner,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repository,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Owner should see:
        // In Day 1 (which has 2 activities): "Thêm hoạt động" button and "Sắp xếp" button
        expect(find.text('Thêm hoạt động'), findsWidgets);
        expect(find.text('Sắp xếp'), findsOneWidget);

        // In Day 2 (which has 0 activities): "Thêm hoạt động đầu tiên" button
        expect(find.text('Thêm hoạt động đầu tiên'), findsOneWidget);

        // Activities should render
        expect(find.text('Uống cà phê Tùng'), findsOneWidget);
        expect(find.text('Dạo Quảng trường Lâm Viên'), findsOneWidget);
      },
    );

    testWidgets(
      'hides Add Activity, Reorder, and Activity popup menus when viewer is NOT owner',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'other_user'},
          token: 'token_other',
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 10,
          presetDetail: testDetailWithOwner,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repository,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Non-owner should NOT see any Activity CRUD or reorder buttons
        expect(find.text('Thêm hoạt động'), findsNothing);
        expect(find.text('Sắp xếp'), findsNothing);
        expect(find.text('Thêm hoạt động đầu tiên'), findsNothing);

        // But should still view the activities
        expect(find.text('Uống cà phê Tùng'), findsOneWidget);
        expect(find.text('Dạo Quảng trường Lâm Viên'), findsOneWidget);
      },
    );

    testWidgets('deleting an activity calls delete API and reloads detail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool deleteApiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/itineraries/10/days/21/activities/301') {
          deleteApiCalled = true;
          return http.Response(
            jsonEncode({'message': 'Đã xóa hoạt động thành công'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'traveler_viet'},
        token: 'token_viet',
      );

      final notifier = FakeItineraryDetailNotifier(
        itineraryId: 10,
        presetDetail: testDetailWithOwner,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 10,
            notifier: notifier,
            authNotifier: authNotifier,
            crudRepository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the popup menu on the activity item
      // Uống cà phê Tùng is the first activity
      final moreButtons = find.byIcon(Icons.more_horiz);
      // Tap on more icon for activity 301
      await tester.tap(moreButtons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Xóa hoạt động'), findsOneWidget);
      await tester.tap(find.text('Xóa hoạt động'));
      await tester.pumpAndSettle();

      // Confirmation dialog opens
      expect(find.text('Xóa hoạt động'), findsWidgets);
      final confirmDeleteBtn = find.widgetWithText(
        ElevatedButton,
        'Xóa hoạt động',
      );
      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      expect(deleteApiCalled, isTrue);
      expect(
        find.textContaining('Đã xóa hoạt động "Uống cà phê Tùng"'),
        findsOneWidget,
      );
    });
  });

  group('Destination Query and Selection Tests', () {
    test(
      'ItineraryCrudRepository.getDestinations parses active destinations',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, equals('/api/destinations'));
          return http.Response(
            jsonEncode([
              {
                'destinationId': 42,
                'name': 'Hồ Tuyền Lâm',
                'address': 'Đà Lạt',
                'description': 'Hồ nước ngọt lớn nhất Đà Lạt',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final list = await repo.getDestinations();
        expect(list.length, equals(1));
        expect(list.first.destinationId, equals(42));
        expect(list.first.name, equals('Hồ Tuyền Lâm'));
      },
    );

    testWidgets(
      'ActivityFormDialog loads destinations and submits with destinationId',
      (tester) async {
        int? submittedDestinationId;
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/destinations') {
            return http.Response(
              jsonEncode([
                {
                  'destinationId': 88,
                  'name': 'Thung Lũng Tình Yêu',
                  'address': 'Phường 8, Đà Lạt',
                },
              ]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path.endsWith('/activities') &&
              request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            submittedDestinationId = body['destinationId'] as int?;
            return http.Response(
              jsonEncode({
                'activityId': 999,
                'name': body['name'],
                'destinationId': submittedDestinationId,
                'orderIndex': 0,
              }),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 200);
        });

        final repo = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final auth = MockAuthNotifier(
          user: {'username': 'testuser'},
          token: 'test_token',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showActivityFormDialog(
                    ctx,
                    itineraryId: 10,
                    dayId: 1,
                    dayNumber: 1,
                    authNotifier: auth,
                    repository: repo,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Thêm hoạt động mới'), findsOneWidget);
        expect(find.text('Điểm đến / Địa điểm (tùy chọn)'), findsOneWidget);

        // Enter activity name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tên hoạt động *'),
          'Dạo chơi ngắm cảnh',
        );

        // Select destination from dropdown
        await tester.tap(find.text('Không liên kết địa điểm'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Thung Lũng Tình Yêu'), findsWidgets);
        await tester.tap(find.textContaining('Thung Lũng Tình Yêu').last);
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.widgetWithText(ElevatedButton, 'Thêm hoạt động'));
        await tester.pumpAndSettle();

        expect(submittedDestinationId, equals(88));
      },
    );
  });

  group('Inline Activity Reordering UX Tests', () {
    final testDetailWithOwner = ItineraryDetail(
      itineraryId: 10,
      title: 'Đà Lạt Mộng Mơ 3N2Đ',
      description: 'Chuyến đi nghỉ dưỡng',
      location: 'Đà Lạt',
      totalDays: 2,
      budget: 3000000.0,
      theme: 'Nghỉ dưỡng',
      visibility: 'PUBLIC',
      status: 'ACTIVE',
      viewCount: 10,
      favoriteCount: 5,
      ratingCount: 3,
      averageRating: 4.8,
      createdAt: DateTime(2026, 10, 20),
      creator: const CreatorSummary(
        userId: 1,
        username: 'traveler_viet',
        fullName: 'Nguyễn Văn Việt',
      ),
      days: [
        ItineraryDayDetail(
          dayId: 21,
          dayNumber: 1,
          title: 'Ngày 1: Check-in & Cà phê',
          date: DateTime(2026, 10, 27),
          activities: [
            const ActivityDetail(
              activityId: 301,
              name: 'Uống cà phê Tùng',
              startTime: '08:00',
              endTime: '09:30',
              displayOrder: 1,
              estimatedCost: 50000.0,
            ),
            const ActivityDetail(
              activityId: 302,
              name: 'Dạo Quảng trường Lâm Viên',
              startTime: '10:00',
              endTime: '11:30',
              displayOrder: 2,
              estimatedCost: 0.0,
            ),
          ],
        ),
        ItineraryDayDetail(
          dayId: 22,
          dayNumber: 2,
          title: 'Ngày 2: Khám phá ngoại thành',
          date: DateTime(2026, 10, 28),
          activities: const [],
        ),
      ],
    );

    testWidgets(
      'Tapping Sắp xếp enters inline reordering mode without opening any overlay or dialog',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'traveler_viet'},
          token: 'token_viet',
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 10,
          presetDetail: testDetailWithOwner,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in normal timeline mode
        expect(find.text('Sắp xếp'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.text('Kéo biểu tượng ≡ để đổi thứ tự hoạt động'),
          findsNothing,
        );

        // Tap "Sắp xếp" button
        await tester.tap(find.text('Sắp xếp'));
        await tester.pumpAndSettle();

        // Confirmed: NO Dialog, NO ModalBottomSheet opened!
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);

        // Inline reorder banner and buttons appear right inside the day card
        expect(
          find.text('Kéo biểu tượng ≡ để đổi thứ tự hoạt động'),
          findsOneWidget,
        );
        expect(find.text('Lưu thứ tự'), findsOneWidget);
        expect(find.text('Hủy'), findsOneWidget);

        // Drag handles are rendered
        expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);
      },
    );

    testWidgets(
      'Canceling reordering restores original order and exits reorder mode',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'traveler_viet'},
          token: 'token_viet',
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 10,
          presetDetail: testDetailWithOwner,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Sắp xếp" to enter inline reorder mode
        await tester.tap(find.text('Sắp xếp'));
        await tester.pumpAndSettle();
        expect(find.text('Lưu thứ tự'), findsOneWidget);

        // Tap "Hủy"
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        // Exits reorder mode, returns to normal timeline
        expect(find.text('Sắp xếp'), findsOneWidget);
        expect(find.text('Lưu thứ tự'), findsNothing);
        expect(
          find.text('Kéo biểu tượng ≡ để đổi thứ tự hoạt động'),
          findsNothing,
        );
      },
    );

    testWidgets('Saving reorder calls backend API and updates detail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool reorderApiCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path ==
                '/api/itineraries/10/days/21/activities/reorder') {
          reorderApiCalled = true;
          return http.Response(
            jsonEncode([
              {'activityId': 301, 'name': 'Uống cà phê Tùng', 'orderIndex': 1},
              {
                'activityId': 302,
                'name': 'Dạo Quảng trường Lâm Viên',
                'orderIndex': 2,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });

      final repository = ItineraryCrudRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final authNotifier = MockAuthNotifier(
        user: {'username': 'traveler_viet'},
        token: 'token_viet',
      );

      final notifier = FakeItineraryDetailNotifier(
        itineraryId: 10,
        presetDetail: testDetailWithOwner,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ItineraryDetailScreen(
            itineraryId: 10,
            notifier: notifier,
            authNotifier: authNotifier,
            crudRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Sắp xếp"
      await tester.tap(find.text('Sắp xếp'));
      await tester.pumpAndSettle();

      // Tap "Lưu thứ tự"
      await tester.tap(find.text('Lưu thứ tự'));
      await tester.pumpAndSettle();

      expect(reorderApiCalled, isTrue);
      expect(find.text('Đã cập nhật thứ tự hoạt động.'), findsOneWidget);
    });

    testWidgets(
      'Failed reorder save displays error SnackBar and restores original order',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient((request) async {
          if (request.method == 'PUT' &&
              request.url.path.contains('/activities/reorder')) {
            return http.Response(
              jsonEncode({'message': 'Lỗi máy chủ khi lưu thứ tự'}),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 200);
        });

        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'traveler_viet'},
          token: 'token_viet',
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 10,
          presetDetail: testDetailWithOwner,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sắp xếp'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưu thứ tự'));
        await tester.pumpAndSettle();

        // Error message appears
        expect(find.text('Lỗi máy chủ khi lưu thứ tự'), findsOneWidget);
        // Original activities remain present
        expect(find.text('Uống cà phê Tùng'), findsOneWidget);
        expect(find.text('Dạo Quảng trường Lâm Viên'), findsOneWidget);
      },
    );

    testWidgets(
      'Inline reordering renders without overflow on a small screen (360x640)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = MockClient(
          (request) async => http.Response('{}', 200),
        );
        final repository = ItineraryCrudRepository(
          apiClient: ApiClient(client: mockClient),
        );
        final authNotifier = MockAuthNotifier(
          user: {'username': 'traveler_viet'},
          token: 'token_viet',
        );

        final notifier = FakeItineraryDetailNotifier(
          itineraryId: 10,
          presetDetail: testDetailWithOwner,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ItineraryDetailScreen(
              itineraryId: 10,
              notifier: notifier,
              authNotifier: authNotifier,
              crudRepository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to make sure "Sắp xếp" is visible if needed
        await tester.scrollUntilVisible(
          find.text('Sắp xếp'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sắp xếp'));
        await tester.pumpAndSettle();

        // Zero exceptions / zero render overflows
        expect(tester.takeException(), isNull);
        expect(find.text('Lưu thứ tự'), findsOneWidget);
      },
    );
  });
}
