import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/comments/data/models/itinerary_comment.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/profile/data/models/public_profile.dart';
import 'package:mobile/features/profile/data/models/public_user_summary.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/profile/data/public_profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/public_profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/public_user_list_screen.dart';

class _MockProfileRepository extends ProfileRepository {
  final Map<String, dynamic> mockProfile;
  _MockProfileRepository(this.mockProfile);

  @override
  Future<Map<String, dynamic>> getProfile(String token) async => mockProfile;

  @override
  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    return {...mockProfile, ...data};
  }
}

class _MockPublicProfileRepo extends PublicProfileRepository {
  final PublicProfile? profile;
  _MockPublicProfileRepo([this.profile]);

  @override
  Future<PublicProfile> getProfile(int id, {String? token}) async =>
      profile ??
      PublicProfile(
        userId: id,
        username: 'user$id',
        handle: 'handle$id',
      );

  @override
  Future<PageResult<PublicUserSummary>> users(
    int id, {
    required bool followers,
    int page = 0,
    String? token,
  }) async =>
      const PageResult(
        content: [
          PublicUserSummary(
            userId: 12,
            username: 'login_hidden_12',
            handle: 'traveler.twelve',
            fullName: 'Twelve Traveler',
          ),
        ],
        pageNumber: 0,
        pageSize: 20,
        totalElements: 1,
        totalPages: 1,
        isLast: true,
      );

  @override
  Future<PageResult<ItinerarySummary>> itineraries(
    int id, {
    int page = 0,
    String? token,
  }) async => const PageResult(
    content: [],
    pageNumber: 0,
    pageSize: 10,
    totalElements: 0,
    totalPages: 0,
    isLast: true,
  );
}

class _FakeAuthNotifier extends ChangeNotifier implements AuthNotifier {
  @override
  String? get token => 'test_token';
  @override
  Map<String, dynamic>? get currentUser => {'username': 'secret_login_acc', 'role': 'USER'};
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  Future<void> updateCurrentUser(Map<String, dynamic> user) async {}
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Decoupled Username and Public Profile Handle', () {
    testWidgets('ProfileScreen displays @handle, shows display name, and hides login username', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockData = {
        'userId': 42,
        'username': 'private_login_username',
        'handle': 'minhdanh.travel',
        'fullName': 'Minh Danh',
        'email': 'danh@example.com',
        'role': 'USER',
        'status': 'ACTIVE',
        'bio': 'Travel enthusiast',
        'createdAt': '2026-10-10T10:00:00',
      };

      final authNotifier = _FakeAuthNotifier();
      final repo = _MockProfileRepository(mockData);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify display name and handle
      expect(find.text('Minh Danh'), findsWidgets);
      expect(find.text('@minhdanh.travel'), findsWidgets);

      // Verify private login username is NOT displayed on the profile screen
      expect(find.text('private_login_username'), findsNothing);
      expect(find.text('@private_login_username'), findsNothing);
      expect(find.text('Tên đăng nhập'), findsNothing);

      // Verify "Định danh (@handle)" label is present in account info
      expect(find.text('Định danh (@handle)'), findsOneWidget);
    });

    testWidgets('ProfileScreen editing validates handle format', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockData = {
        'userId': 42,
        'username': 'private_login_username',
        'handle': 'minhdanh',
        'fullName': 'Minh Danh',
        'email': 'danh@example.com',
        'role': 'USER',
        'status': 'ACTIVE',
      };

      final authNotifier = _FakeAuthNotifier();
      final repo = _MockProfileRepository(mockData);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter editing mode
      await tester.tap(find.text('Chỉnh sửa hồ sơ'));
      await tester.pumpAndSettle();

      expect(find.text('Định danh công khai (@handle)'), findsOneWidget);

      // Try entering invalid handle with spaces (2nd TextFormField is handle)
      final handleField = find.byType(TextFormField).at(1);
      await tester.enterText(handleField, 'invalid handle');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉ chấp nhận chữ thường, số, dấu chấm và gạch dưới'), findsOneWidget);

      // Try entering handle too short (< 3)
      await tester.enterText(handleField, 'ab');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(find.text('Handle phải từ 3 đến 30 ký tự'), findsOneWidget);

      // Entering handle with leading @ is normalized and accepted
      await tester.enterText(handleField, '@danh.travel2');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(find.text('Đã cập nhật hồ sơ'), findsOneWidget);
      expect(find.text('@danh.travel2'), findsWidgets);
    });

    testWidgets('ProfileScreen displays "Chưa thiết lập" when handle is null or empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockData = {
        'userId': 42,
        'username': 'private_login_username',
        'handle': null,
        'fullName': 'Minh Danh',
        'email': 'danh@example.com',
        'role': 'USER',
        'status': 'ACTIVE',
      };

      final authNotifier = _FakeAuthNotifier();
      final repo = _MockProfileRepository(mockData);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authNotifier: authNotifier,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa thiết lập'), findsOneWidget);
    });

    testWidgets('PublicProfileScreen displays @handle and hides login username', (tester) async {
      const publicProfile = PublicProfile(
        userId: 99,
        username: 'secret_login_99',
        handle: 'public.nomad',
        fullName: 'Wanderer Nomad',
        bio: 'Exploring the world',
        followerCount: 10,
        followingCount: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PublicProfileScreen(
            userId: 99,
            repository: _MockPublicProfileRepo(publicProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wanderer Nomad'), findsWidgets);
      expect(find.text('@public.nomad'), findsOneWidget);

      // Strictly assert secret login username is never displayed
      expect(find.text('secret_login_99'), findsNothing);
      expect(find.text('@secret_login_99'), findsNothing);
    });

    testWidgets('PublicUserListScreen displays @handle in subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicUserListScreen(
              userId: 12,
              followers: true,
              repository: _MockPublicProfileRepo(),
              onUserSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Twelve Traveler'), findsOneWidget);
      expect(find.text('@traveler.twelve'), findsOneWidget);
      expect(find.text('login_hidden_12'), findsNothing);
      expect(find.text('@login_hidden_12'), findsNothing);
    });

    test('CreatorSummary displayName prefers fullName, falls back to @handle, never username', () {
      final withFullName = CreatorSummary.fromJson({
        'userId': 1,
        'username': 'hidden_login_1',
        'handle': 'public_handle_1',
        'fullName': 'Nguyễn Văn A',
      });
      expect(withFullName.displayName, 'Nguyễn Văn A');

      final withHandleOnly = CreatorSummary.fromJson({
        'userId': 2,
        'username': 'hidden_login_2',
        'handle': 'public_handle_2',
        'fullName': '',
      });
      expect(withHandleOnly.displayName, '@public_handle_2');

      final emptyFallback = CreatorSummary.fromJson({
        'userId': 3,
        'username': 'hidden_login_3',
        'handle': '',
        'fullName': null,
      });
      expect(emptyFallback.displayName, 'Người dùng');
      expect(emptyFallback.displayName, isNot(contains('hidden_login_3')));
    });

    test('ItineraryComment displayName and replyToName decouple from username', () {
      final comment = ItineraryComment.fromJson({
        'commentId': 100,
        'content': 'Tuyệt vời!',
        'creator': {
          'userId': 5,
          'username': 'private_user_5',
          'handle': 'traveler_five',
          'fullName': null,
        },
        'replyToCreator': {
          'userId': 6,
          'username': 'private_user_6',
          'handle': 'traveler_six',
          'fullName': null,
        },
      });

      expect(comment.displayName, '@traveler_five');
      expect(comment.replyToName, '@traveler_six');
      expect(comment.displayName, isNot(contains('private_user_5')));
      expect(comment.replyToName, isNot(contains('private_user_6')));
    });
  });
}
