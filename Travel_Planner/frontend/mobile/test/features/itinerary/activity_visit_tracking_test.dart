import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_day_detail.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/itinerary_detail_notifier.dart';
import 'package:mobile/features/itinerary/presentation/screens/activity_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/widgets/activity_visit_swipe_action.dart';
import 'package:mobile/features/itinerary/presentation/widgets/navigation_launcher_helper.dart';
import 'package:mobile/shared/services/device_location_service.dart';
import 'package:mobile/shared/widgets/map_marker_builder.dart';
import 'package:url_launcher/url_launcher.dart';

class _FakeLocationService extends DeviceLocationService {
  final LatLng location;

  _FakeLocationService(this.location);

  @override
  Future<LatLng> getCurrentLocation() async => location;
}

class _FakeVisitRepository extends ItineraryCrudRepository {
  final bool shouldFail;
  int updateCount = 0;

  _FakeVisitRepository({this.shouldFail = false});

  @override
  Future<void> updateActivityVisitStatus({
    required int itineraryId,
    required int dayId,
    required int activityId,
    required bool visited,
    String? token,
  }) async {
    updateCount++;
    if (shouldFail) throw StateError('request failed');
  }
}

void main() {
  group('Activity visit model and Google Maps directions', () {
    test('parses visited and defaults missing legacy state to false', () {
      final visited = ActivityDetail.fromJson({
        'activityId': 7,
        'name': 'Bưu điện thành phố',
        'displayOrder': 1,
        'visited': true,
      });
      final legacy = ActivityDetail.fromJson({
        'activityId': 8,
        'name': 'Nhà thờ Đức Bà',
        'displayOrder': 2,
        'visited': null,
      });

      expect(visited.visited, isTrue);
      expect(legacy.visited, isFalse);
      expect(legacy.copyWith(visited: true).visited, isTrue);
      expect(legacy.visited, isFalse);
    });

    test('builds directions from the current location to exact activity coordinates', () {
      final uri = NavigationLauncherHelper.buildCurrentLocationDirectionsUri(
        origin: const LatLng(10.1, 106.2),
        destinationPoint: const LatLng(10.7, 106.6),
        destinationName: 'Ignored display label',
      );

      expect(uri!.path, '/maps/dir/');
      expect(uri.queryParameters['origin'], '10.1,106.2');
      expect(uri.queryParameters['destination'], '10.7,106.6');
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('uses address when activity coordinates are unavailable', () {
      final uri = NavigationLauncherHelper.buildCurrentLocationDirectionsUri(
        origin: const LatLng(10.1, 106.2),
        destinationAddress: '12 Nguyễn Huệ, Quận 1',
      );

      expect(uri!.queryParameters['destination'], '12 Nguyễn Huệ, Quận 1');
      expect(
        NavigationLauncherHelper.buildCurrentLocationDirectionsUri(
          origin: const LatLng(10.1, 106.2),
        ),
        isNull,
      );
    });

    test(
      'visit status repository sends an authenticated PUT with boolean body',
      () async {
        late http.Request request;
        final apiClient = ApiClient(
          client: MockClient((incoming) async {
            request = incoming;
            return http.Response('{}', 200);
          }),
        );
        final repository = ItineraryCrudRepository(apiClient: apiClient);

        await repository.updateActivityVisitStatus(
          itineraryId: 5,
          dayId: 6,
          activityId: 7,
          visited: true,
          token: 'test-token',
        );

        expect(request.method, 'PUT');
        expect(
          request.url.path,
          endsWith('/api/itineraries/5/days/6/activities/7/visit-status'),
        );
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {'visited': true});
      },
    );

    test(
      'notifier optimistically updates one activity and rolls back on error',
      () async {
        final initialActivity = const ActivityDetail(
          activityId: 70,
          name: 'Điểm tham quan',
          displayOrder: 1,
        );
        final initialDetail = ItineraryDetail(
          itineraryId: 5,
          title: 'Lịch trình thử',
          location: 'Đà Lạt',
          totalDays: 1,
          budget: 0,
          viewCount: 0,
          favoriteCount: 0,
          ratingCount: 0,
          averageRating: 0,
          visibility: 'PUBLIC',
          status: 'ACTIVE',
          days: [
            ItineraryDayDetail(
              dayId: 6,
              dayNumber: 1,
              activities: [initialActivity],
            ),
          ],
        );
        final successRepository = _FakeVisitRepository();
        final notifier = ItineraryDetailNotifier(
          itineraryId: 5,
          initialDetail: initialDetail,
          crudRepository: successRepository,
        );

        final success = await notifier.updateActivityVisitedStatus(
          dayId: 6,
          activityId: 70,
          visited: true,
          token: 'token',
        );
        expect(success, isTrue);
        expect(
          notifier.itineraryDetail!.days.single.activities.single.visited,
          isTrue,
        );
        expect(successRepository.updateCount, 1);

        final failedNotifier = ItineraryDetailNotifier(
          itineraryId: 5,
          initialDetail: notifier.itineraryDetail,
          crudRepository: _FakeVisitRepository(shouldFail: true),
        );
        final failed = await failedNotifier.updateActivityVisitedStatus(
          dayId: 6,
          activityId: 70,
          visited: false,
          token: 'token',
        );
        expect(failed, isFalse);
        expect(
          failedNotifier.itineraryDetail!.days.single.activities.single.visited,
          isTrue,
        );
      },
    );

    testWidgets(
      'unvisited action is revealed behind the row by right swipe and updates on tap',
      (tester) async {
        var updated = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityVisitSwipeAction(
                activity: const ActivityDetail(
                  activityId: 3,
                  name: 'Chợ Bến Thành',
                  displayOrder: 1,
                ),
                onUpdate: (visited) async {
                  updated = visited;
                  return true;
                },
                child: const SizedBox(
                  height: 70,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(child: Text('Activity row')),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.text('Activity row'), const Offset(180, 0));
        await tester.pumpAndSettle();
        expect(find.text('Đã ghé thăm'), findsOneWidget);
        expect(updated, isFalse);

        await tester.tap(find.text('Đã ghé thăm'));
        await tester.pumpAndSettle();
        expect(updated, isTrue);
      },
    );

    testWidgets('a short swipe settles back without updating visit status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var updateCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityVisitSwipeAction(
              activity: const ActivityDetail(
                activityId: 4,
                name: 'Nhà thờ Đức Bà',
                displayOrder: 2,
              ),
              onUpdate: (_) async {
                updateCount++;
                return true;
              },
              child: const SizedBox(
                height: 70,
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('Short swipe row')),
                ),
              ),
            ),
          ),
        ),
      );

      final initialLeft = tester.getTopLeft(find.text('Short swipe row')).dx;
      await tester.drag(find.text('Short swipe row'), const Offset(25, 0));
      await tester.pumpAndSettle();

      expect(updateCount, 0);
      expect(tester.getTopLeft(find.text('Short swipe row')).dx, initialLeft);
      final rowRect = tester.getRect(find.text('Short swipe row'));
      await tester.tapAt(Offset(rowRect.left + 24, rowRect.center.dy));
      await tester.pumpAndSettle();
      expect(updateCount, 0, reason: 'A hidden action must not receive taps');
    });

    testWidgets('visited action opens from the left by swiping right', (
      tester,
    ) async {
      var updatedVisited = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityVisitSwipeAction(
              activity: const ActivityDetail(
                activityId: 5,
                name: 'Bưu điện thành phố',
                displayOrder: 1,
                visited: true,
              ),
              onUpdate: (visited) async {
                updatedVisited = visited;
                return true;
              },
              child: const SizedBox(
                height: 70,
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('Visited row')),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Visited row'), const Offset(180, 0));
      await tester.pumpAndSettle();
      expect(find.text('Chưa ghé thăm'), findsOneWidget);
      expect(updatedVisited, isTrue);

      await tester.tap(find.text('Chưa ghé thăm'));
      await tester.pumpAndSettle();
      expect(updatedVisited, isFalse);
    });

    testWidgets('visited map marker shows a check instead of its sequence', (
      tester,
    ) async {
      final marker = MapMarkerBuilder.buildStopMarker(
        point: const LatLng(10, 106),
        sequence: 4,
        visited: true,
        semanticLabel: 'Đã ghé điểm thử',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: marker.child)),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('4'), findsNothing);
    });

    testWidgets(
      'activity directions uses injected current GPS and activity target',
      (tester) async {
        Uri? launchedUri;
        final activity = ActivityDetail(
          activityId: 10,
          name: 'Bưu điện thành phố',
          displayOrder: 1,
          latitude: 10.7769,
          longitude: 106.7009,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityDirectionsButton(
                activity: activity,
                locationService: _FakeLocationService(
                  const LatLng(10.8, 106.7),
                ),
                launcher:
                    (
                      uri, {
                      LaunchMode mode = LaunchMode.platformDefault,
                    }) async {
                      launchedUri = uri;
                      return true;
                    },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Chỉ đường'));
        await tester.pumpAndSettle();

        expect(launchedUri?.path, '/maps/dir/');
        expect(launchedUri?.queryParameters['origin'], '10.8,106.7');
        expect(launchedUri?.queryParameters['destination'], '10.7769,106.7009');
      },
    );

    testWidgets(
      'duplicate taps do not launch duplicate routes while location is pending',
      (tester) async {
        final locationCompleter = Completer<LatLng>();
        var launchCount = 0;
        final locationService = _PendingLocationService(
          locationCompleter.future,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActivityDirectionsButton(
                activity: const ActivityDetail(
                  activityId: 11,
                  name: 'Bưu điện thành phố',
                  displayOrder: 1,
                  latitude: 10.7769,
                  longitude: 106.7009,
                ),
                locationService: locationService,
                launcher:
                    (
                      uri, {
                      LaunchMode mode = LaunchMode.platformDefault,
                    }) async {
                      launchCount++;
                      return true;
                    },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Chỉ đường'));
        await tester.pump();
        await tester.tap(find.byType(OutlinedButton));
        await tester.pump();
        expect(launchCount, 0);

        locationCompleter.complete(const LatLng(10.8, 106.7));
        await tester.pumpAndSettle();
        expect(launchCount, 1);
      },
    );
  });
}

class _PendingLocationService extends DeviceLocationService {
  final Future<LatLng> pendingLocation;

  _PendingLocationService(this.pendingLocation);

  @override
  Future<LatLng> getCurrentLocation() => pendingLocation;
}
