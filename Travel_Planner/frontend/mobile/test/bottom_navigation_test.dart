import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/explore/data/explore_repository.dart';
import 'package:mobile/features/explore/presentation/explore_notifier.dart';
import 'package:mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:mobile/features/itinerary/data/itinerary_crud_repository.dart';
import 'package:mobile/features/itinerary/presentation/screens/create_itinerary_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/saved_itineraries/presentation/screens/saved_itineraries_screen.dart';
import 'package:mobile/features/social/presentation/screens/community_screen.dart';
import 'package:mobile/shared/navigation/main_navigation_shell.dart';

class MockAuthNotifier extends AuthNotifier {
  @override
  final Map<String, dynamic>? currentUser;

  @override
  final String? token;

  MockAuthNotifier({this.currentUser, this.token});

  @override
  bool get isAuthenticated => token != null;
}

void main() {
  late MockClient mockClient;
  late ApiClient apiClient;
  late ExploreRepository exploreRepository;
  late ExploreNotifier exploreNotifier;
  late ItineraryCrudRepository itineraryRepository;
  late ProfileRepository profileRepository;
  late MockAuthNotifier authNotifier;

  setUp(() {
    mockClient = MockClient((request) async {
      if (request.url.path.contains('/api/itineraries') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'itineraryId': 1,
                'title': 'Khám phá Đà Nẵng 3N2Đ',
                'location': 'Đà Nẵng',
                'totalDays': 3,
                'budget': 2500000.0,
                'theme': 'Khám phá',
                'viewCount': 10,
                'favoriteCount': 2,
                'ratingCount': 1,
                'averageRating': 5.0,
              },
            ],
            'pageNumber': 0,
            'pageSize': 10,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      } else if (request.url.path.contains('/api/itineraries') &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'itineraryId': 99,
            'title': 'Hành trình mới',
            'location': 'Hà Giang',
            'totalDays': 3,
            'budget': 3000000.0,
            'theme': 'Phượt',
            'visibility': 'PRIVATE',
            'status': 'ACTIVE',
            'createdAt': '2026-10-28T12:00:00Z',
            'creator': {
              'userId': 1,
              'username': 'traveler_viet',
              'fullName': 'Nguyễn Văn Du Lịch',
            },
            'days': [],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      } else if (request.url.path.contains('/api/user/profile')) {
        return http.Response(
          jsonEncode({
            'userId': 1,
            'username': 'traveler_viet',
            'fullName': 'Nguyễn Văn Du Lịch',
            'email': 'viet@example.com',
            'bio': 'Yêu thích du lịch tự túc',
            'phone': '0901234567',
            'address': 'Hà Nội',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });

    apiClient = ApiClient(client: mockClient);
    exploreRepository = ExploreRepository(apiClient: apiClient);
    exploreNotifier = ExploreNotifier(repository: exploreRepository);
    itineraryRepository = ItineraryCrudRepository(apiClient: apiClient);
    profileRepository = ProfileRepository(apiClient: apiClient);
    authNotifier = MockAuthNotifier(
      currentUser: {
        'userId': 1,
        'username': 'traveler_viet',
        'fullName': 'Nguyễn Văn Du Lịch',
      },
      token: 'valid_test_token',
    );
  });

  Widget buildTestShell({
    AuthNotifier? customAuthNotifier,
    int initialIndex = 0,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MainNavigationShell(
        authNotifier: customAuthNotifier ?? authNotifier,
        exploreNotifier: exploreNotifier,
        itineraryRepository: itineraryRepository,
        profileRepository: profileRepository,
        initialIndex: initialIndex,
      ),
    );
  }

  group('Bottom Navigation Bar Structure & Destinations', () {
    testWidgets(
      'displays exactly five icon-only destinations in the specified order without text labels',
      (tester) async {
        await tester.pumpWidget(buildTestShell());
        await tester.pumpAndSettle();

        final bottomNavFinder = find.byType(BottomNavigationBar);
        expect(bottomNavFinder, findsOneWidget);

        final bottomNav = tester.widget<BottomNavigationBar>(bottomNavFinder);
        expect(bottomNav.items.length, equals(5));
        expect(bottomNav.showSelectedLabels, isFalse);
        expect(bottomNav.showUnselectedLabels, isFalse);

        // Verify destination item labels for accessibility tooltips / semantics
        expect(bottomNav.items[0].label, equals('Khám phá'));
        expect(bottomNav.items[1].label, equals('Cộng đồng'));
        expect(bottomNav.items[2].label, equals('Tạo lịch trình'));
        expect(bottomNav.items[3].label, equals('Đã lưu'));
        expect(bottomNav.items[4].label, equals('Hồ sơ'));

        // Verify correct icons
        expect(find.byIcon(Icons.explore), findsOneWidget); // selected
        expect(find.byIcon(Icons.group_outlined), findsOneWidget);
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      },
    );

    testWidgets('Explore is the default destination (index 0)', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();

      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, equals(0));
      expect(find.byType(ExploreScreen), findsOneWidget);
    });

    testWidgets(
      'Tapping each destination updates selected index and renders the correct screen',
      (tester) async {
        await tester.pumpWidget(buildTestShell());
        await tester.pumpAndSettle();

        // 1. Tap Community (Index 1)
        await tester.tap(find.byIcon(Icons.group_outlined));
        await tester.pumpAndSettle();

        var bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bottomNav.currentIndex, equals(1));
        expect(find.byType(CommunityScreen), findsOneWidget);
        expect(find.text('Cộng đồng du lịch'), findsOneWidget);

        // 2. Tap Create Itinerary (Index 2)
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bottomNav.currentIndex, equals(2));
        expect(find.byType(CreateItineraryScreen), findsOneWidget);
        expect(find.text('Tiêu đề lịch trình *'), findsOneWidget);

        // 3. Tap Saved Itineraries (Index 3)
        await tester.tap(find.byIcon(Icons.bookmark_outline));
        await tester.pumpAndSettle();

        bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bottomNav.currentIndex, equals(3));
        expect(find.byType(SavedItinerariesScreen), findsOneWidget);
        expect(find.text('Lịch trình đã lưu'), findsWidgets);

        // 4. Tap Profile (Index 4)
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();

        bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bottomNav.currentIndex, equals(4));
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text('Hồ sơ cá nhân'), findsOneWidget);

        // 5. Tap Explore (Index 0)
        await tester.tap(find.byIcon(Icons.explore_outlined));
        await tester.pumpAndSettle();

        bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bottomNav.currentIndex, equals(0));
        expect(find.byType(ExploreScreen), findsOneWidget);
      },
    );

    testWidgets('Preserves input state when switching between tabs', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();

      // Go to Create tab
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // Enter custom text in the title field
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ví dụ: Khám phá Đà Lạt 3 ngày 2 đêm'),
        'Chuyến đi phượt Tây Bắc',
      );
      await tester.pump();

      // Switch to Community tab
      await tester.tap(find.byIcon(Icons.group_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Cộng đồng du lịch'), findsOneWidget);

      // Switch back to Create tab
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      // Form text should be preserved by IndexedStack
      expect(find.text('Chuyến đi phượt Tây Bắc'), findsOneWidget);
    });
  });

  group('Notifications Entry Point & UI', () {
    testWidgets(
      'Notification bell in Explore top-right opens empty NotificationsScreen',
      (tester) async {
        await tester.pumpWidget(buildTestShell());
        await tester.pumpAndSettle();

        // Find notification bell icon in AppBar
        final bellFinder = find.widgetWithIcon(IconButton, Icons.notifications_outlined);
        expect(bellFinder, findsWidgets);

        // Tap the bell on ExploreScreen
        await tester.tap(bellFinder.first);
        await tester.pumpAndSettle();

        // Verify NotificationsScreen opened
        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.text('Thông báo'), findsOneWidget);
        expect(find.text('Chưa có thông báo'), findsOneWidget);
      },
    );

    testWidgets(
      'ExploreScreen top-right app bar displays only notification bell and no profile dropdown when authenticated',
      (tester) async {
        await tester.pumpWidget(buildTestShell());
        await tester.pumpAndSettle();

        // Verify notification bell is displayed
        expect(
          find.widgetWithIcon(IconButton, Icons.notifications_outlined),
          findsWidgets,
        );

        // Verify no profile avatar or dropdown in AppBar
        expect(find.byType(PopupMenuButton), findsNothing);
        expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
        expect(find.text('traveler_viet'), findsNothing);
        expect(find.text('Nguyễn Văn Du Lịch'), findsNothing);
      },
    );

    testWidgets(
      'ProfileScreen provides access to MyItinerariesScreen',
      (tester) async {
        await tester.pumpWidget(buildTestShell(initialIndex: 4));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Lịch trình của tôi'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Lịch trình của tôi'), findsOneWidget);

        await tester.tap(find.text('Lịch trình của tôi'));
        await tester.pumpAndSettle();

        expect(find.text('Lịch trình của tôi'), findsWidgets);
      },
    );

    testWidgets(
      'Notification bell in Community top-right opens NotificationsScreen',
      (tester) async {
        await tester.pumpWidget(buildTestShell(initialIndex: 1));
        await tester.pumpAndSettle();

        expect(find.byType(CommunityScreen), findsOneWidget);
        final bellFinder = find.widgetWithIcon(IconButton, Icons.notifications_outlined);
        await tester.tap(bellFinder.first);
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.text('Chưa có thông báo'), findsOneWidget);
      },
    );

    testWidgets(
      'Notification bell in SavedItineraries top-right opens NotificationsScreen',
      (tester) async {
        await tester.pumpWidget(buildTestShell(initialIndex: 3));
        await tester.pumpAndSettle();

        expect(find.byType(SavedItinerariesScreen), findsOneWidget);
        final bellFinder = find.widgetWithIcon(IconButton, Icons.notifications_outlined);
        await tester.tap(bellFinder.first);
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.text('Chưa có thông báo'), findsOneWidget);
      },
    );
  });

  group('Authentication & Modal Route Scoping', () {
    testWidgets(
      'LoginScreen and RegisterScreen do not show bottom navigation bar',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LoginScreen(authNotifier: authNotifier),
                      ),
                    );
                  },
                  child: const Text('Mở đăng nhập'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mở đăng nhập'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);

        // Tap register
        await tester.tap(find.text('Đăng ký ngay'));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);
      },
    );

    testWidgets(
      'ProfileScreen in guest mode renders login prompt and does not hang',
      (tester) async {
        final guestAuth = MockAuthNotifier(); // token == null
        await tester.pumpWidget(buildTestShell(customAuthNotifier: guestAuth, initialIndex: 4));
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text('Chưa đăng nhập'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Đăng nhập'), findsOneWidget);
      },
    );
  });

  group('Layout & Safe Area Tests', () {
    testWidgets('renders cleanly without overflow on small screen (360x640)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestShell());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Cycle through each tab to verify no constraint or overflow errors
      for (final icon in [
        Icons.group_outlined,
        Icons.add_circle_outline,
        Icons.bookmark_outline,
        Icons.person_outline,
        Icons.explore_outlined,
      ]) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
