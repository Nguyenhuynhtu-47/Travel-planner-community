import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/collection/presentation/screens/collection_screen.dart';
import 'package:mobile/features/explore/data/models/creator_summary.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/presentation/widgets/itinerary_card.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_detail.dart';
import 'package:mobile/features/itinerary/presentation/screens/itinerary_detail_screen.dart';
import 'package:mobile/features/itinerary/presentation/screens/my_itineraries_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:mobile/features/social/presentation/screens/community_feed_screen.dart';
import 'package:mobile/shared/services/image_picker_service.dart';
import 'package:mobile/shared/widgets/current_user_avatar_button.dart';
import 'package:mobile/shared/widgets/image_upload_preview.dart';

class MockProfileRepo extends ProfileRepository {
  final Map<String, dynamic> data;
  MockProfileRepo(this.data);

  @override
  Future<Map<String, dynamic>> getProfile(String token) async => data;

  @override
  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> updateData,
  ) async =>
      {...data, ...updateData};
}

class MockAuthNotifier extends AuthNotifier {
  final Map<String, dynamic>? _user;
  final bool _authenticated;

  MockAuthNotifier({Map<String, dynamic>? user, this._authenticated = true})
      : _user = user ?? {'userId': 100, 'username': 'current_user', 'avatar': ''};

  @override
  String? get token => _authenticated ? 'valid_test_token' : null;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  Map<String, dynamic>? get currentUser => _user;
}

class FakeImagePickerService implements ImagePickerService {
  @override
  Future<XFile?> pickImage() async => null;
}

ItinerarySummary makeSummary({
  required int id,
  int creatorId = 200,
  String creatorUsername = 'other_user',
}) {
  return ItinerarySummary(
    itineraryId: id,
    title: 'Hành trình số $id',
    location: 'Đà Lạt, Lâm Đồng',
    totalDays: 3,
    budget: 2500000,
    viewCount: 150,
    favoriteCount: 12,
    ratingCount: 5,
    averageRating: 4.8,
    creator: CreatorSummary(
      userId: creatorId,
      username: creatorUsername,
      fullName: 'Người tạo $creatorId',
    ),
  );
}

ItineraryDetail makeDetail({
  required int id,
  int creatorId = 200,
  String creatorUsername = 'other_user',
  bool isSaved = false,
  bool isFavorited = false,
}) {
  return ItineraryDetail(
    itineraryId: id,
    title: 'Chi tiết hành trình $id',
    location: 'Đà Lạt',
    totalDays: 2,
    budget: 1500000,
    viewCount: 100,
    favoriteCount: 10,
    ratingCount: 3,
    averageRating: 4.5,
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    isSaved: isSaved,
    isFavorited: isFavorited,
    days: const [],
    creator: CreatorSummary(
      userId: creatorId,
      username: creatorUsername,
      fullName: 'Người tạo $creatorId',
    ),
  );
}

void main() {
  group('Requirement 1 & 2: Avatar & Notification on AppBars', () {
    testWidgets('CollectionScreen AppBar displays CurrentUserAvatarButton and navigates to Profile', (tester) async {
      final authNotifier = MockAuthNotifier(
        user: {'userId': 100, 'username': 'tester', 'avatar': 'https://example.com/avatar.jpg'},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CollectionScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      final avatarFinder = find.byType(CurrentUserAvatarButton);
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('CommunityFeedScreen AppBar displays CurrentUserAvatarButton and navigates to Profile', (tester) async {
      final authNotifier = MockAuthNotifier(
        user: {'userId': 100, 'username': 'tester', 'avatar': ''},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CommunityFeedScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      final avatarFinder = find.byType(CurrentUserAvatarButton);
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('MyItinerariesScreen AppBar displays Notification icon and CurrentUserAvatarButton', (tester) async {
      final authNotifier = MockAuthNotifier(
        user: {'userId': 100, 'username': 'tester', 'avatar': ''},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MyItinerariesScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      final notifFinder = find.byTooltip('Thông báo');
      expect(notifFinder, findsOneWidget);

      final avatarFinder = find.byType(CurrentUserAvatarButton);
      expect(avatarFinder, findsOneWidget);

      // Tapping notification icon navigates to NotificationsScreen
      await tester.tap(notifFinder);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);

      // Pop back
      Navigator.of(tester.element(find.byType(NotificationsScreen))).pop();
      await tester.pumpAndSettle();

      // Tapping avatar button navigates to ProfileScreen
      await tester.tap(find.byType(CurrentUserAvatarButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  group('Requirement 3: Profile Update Avatar Position', () {
    testWidgets('ImageUploadPreview is positioned above personal info fields in Profile edit form', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockData = {
        'userId': 100,
        'username': 'tester',
        'fullName': 'Nguyễn Văn A',
        'handle': 'tester_travel',
        'avatar': '',
      };

      final authNotifier = MockAuthNotifier(user: mockData);
      final repo = MockProfileRepo(mockData);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            authNotifier: authNotifier,
            repository: repo,
            imagePickerService: FakeImagePickerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on edit profile button
      final editBtn = find.text('Chỉnh sửa hồ sơ');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify ImageUploadPreview is present in edit form
      final avatarUploadFinder = find.byType(ImageUploadPreview);
      expect(avatarUploadFinder, findsOneWidget);

      final nameFieldFinder = find.widgetWithText(TextFormField, 'Nguyễn Văn A');
      expect(nameFieldFinder, findsOneWidget);

      final avatarY = tester.getTopLeft(avatarUploadFinder).dy;
      final nameY = tester.getTopLeft(nameFieldFinder).dy;
      // Avatar preview must be vertically ABOVE the full name field
      expect(avatarY < nameY, isTrue, reason: 'Avatar preview must be placed above the name field');
    });
  });

  group('Requirement 4: Hide Save and Favorite Icons on Own Itineraries', () {
    testWidgets('ItineraryDetailScreen: Own itinerary hides Save (bookmark) and Favorite (heart) actions', (tester) async {
      final authNotifier = MockAuthNotifier(
        user: {'userId': 100, 'username': 'my_account'},
      );

      // Itinerary owned by current user (userId == 100)
      final ownDetail = makeDetail(
        id: 55,
        creatorId: 100,
        creatorUsername: 'my_account',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ItineraryDetailScreen(
            itineraryId: 55,
            initialDetail: ownDetail,
            isOwner: true,
            authNotifier: authNotifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify neither bookmark nor favorite actions are shown in AppBar
      expect(find.byTooltip('Lưu lịch trình'), findsNothing);
      expect(find.byTooltip('Bỏ lưu'), findsNothing);
      expect(find.byTooltip('Yêu thích'), findsNothing);
      expect(find.byTooltip('Bỏ yêu thích'), findsNothing);
    });

    testWidgets('ItineraryDetailScreen: Other user itinerary shows both Save and Favorite actions', (tester) async {
      final authNotifier = MockAuthNotifier(
        user: {'userId': 100, 'username': 'my_account'},
      );

      // Itinerary owned by someone else (creatorId == 999)
      final otherDetail = makeDetail(
        id: 77,
        creatorId: 999,
        creatorUsername: 'other_author',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ItineraryDetailScreen(
            itineraryId: 77,
            initialDetail: otherDetail,
            isOwner: false,
            authNotifier: authNotifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both bookmark and favorite actions are rendered
      expect(find.byTooltip('Lưu lịch trình'), findsOneWidget);
      expect(find.byTooltip('Yêu thích'), findsOneWidget);
    });

    testWidgets('ItineraryDetailScreen: Sample template itinerary without owner shows both actions', (tester) async {
      final authNotifier = MockAuthNotifier(
        user: {'userId': 100, 'username': 'my_account'},
      );

      // System template itinerary with no creator
      const templateDetail = ItineraryDetail(
        itineraryId: 88,
        title: 'Mẫu lịch trình Đà Nẵng 3 ngày',
        location: 'Đà Nẵng',
        totalDays: 3,
        budget: 2000000,
        viewCount: 50,
        favoriteCount: 25,
        ratingCount: 10,
        averageRating: 4.8,
        visibility: 'PUBLIC',
        status: 'ACTIVE',
        days: [],
        creator: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ItineraryDetailScreen(
            itineraryId: 88,
            initialDetail: templateDetail,
            isOwner: false,
            authNotifier: authNotifier,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both bookmark and favorite actions are rendered for sample itinerary
      expect(find.byTooltip('Lưu lịch trình'), findsOneWidget);
      expect(find.byTooltip('Yêu thích'), findsOneWidget);
    });

    testWidgets('ItineraryCard: showFavorite = false completely hides favorite button with no gap', (tester) async {
      final item = makeSummary(id: 1, creatorId: 100, creatorUsername: 'current_user');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryCard(
                itinerary: item,
                showFavorite: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('ItineraryCard: showFavorite = true with onFavoriteTap renders favorite heart icon', (tester) async {
      final item = makeSummary(id: 2, creatorId: 200, creatorUsername: 'other_user');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryCard(
                itinerary: item,
                showFavorite: true,
                onFavoriteTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });
  });
}
