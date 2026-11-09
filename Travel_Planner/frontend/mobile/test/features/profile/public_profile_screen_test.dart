import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/data/models/page_result.dart';
import 'package:mobile/features/profile/data/public_profile_repository.dart';
import 'package:mobile/features/profile/data/models/public_profile.dart';
import 'package:mobile/features/profile/presentation/screens/public_profile_screen.dart';

class _PublicRepository extends PublicProfileRepository {
  @override
  Future<PublicProfile> getProfile(int id, {String? token}) async =>
      PublicProfile(
        userId: id,
        username: 'traveler',
        fullName: 'Public Name',
        bio: 'Travel bio',
        followerCount: 3,
        followingCount: 4,
        isFollowing: false,
        isOwnProfile: false,
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

void main() {
  testWidgets(
    'hồ sơ công khai chỉ hiển thị dữ liệu công khai và trạng thái rỗng',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicProfileScreen(userId: 5, repository: _PublicRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Public Name'), findsWidgets);
      expect(find.text('@traveler'), findsOneWidget);
      expect(find.text('Travel bio'), findsOneWidget);
      expect(find.text('private@example.com'), findsNothing);
      expect(find.text('12345'), findsNothing);
      expect(find.text('Private address'), findsNothing);
      expect(find.text('Chưa có lịch trình công khai'), findsOneWidget);
      expect(find.text('Theo dõi'), findsOneWidget);
    },
  );
}
