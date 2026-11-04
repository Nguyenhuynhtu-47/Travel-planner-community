import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/collection/presentation/collection_notifier.dart';
import 'package:mobile/features/collection/presentation/screens/collection_screen.dart';
import 'package:mobile/features/explore/presentation/widgets/itinerary_card.dart';

import 'collection_notifier_test.dart';

class MockTestAuthNotifier extends AuthNotifier {
  @override
  String? get token => 'test_token';
  @override
  bool get isAuthenticated => true;
  @override
  Map<String, dynamic>? get currentUser => {'userId': 1, 'username': 'test_user'};
}

void main() {
  late FakeCollectionRepository fakeRepo;
  late CollectionNotifier notifier;
  late MockTestAuthNotifier authNotifier;

  setUp(() {
    fakeRepo = FakeCollectionRepository();
    notifier = CollectionNotifier(repository: fakeRepo);
    authNotifier = MockTestAuthNotifier();
  });

  Widget buildTestScreen() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: CollectionScreen(
        authNotifier: authNotifier,
        notifier: notifier,
      ),
    );
  }

  testWidgets('CollectionScreen renders AppBar and both tabs', (tester) async {
    await tester.pumpWidget(buildTestScreen());
    await tester.pumpAndSettle();

    expect(find.text('Bộ sưu tập'), findsOneWidget);
    expect(find.text('Đã lưu'), findsOneWidget);
    expect(find.text('Yêu thích'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('Shows empty state when no saved or favorite itineraries', (tester) async {
    fakeRepo.savedResponse = [];
    fakeRepo.favoriteResponse = [];

    await tester.pumpWidget(buildTestScreen());
    await tester.pumpAndSettle();

    expect(find.text('Chưa có lịch trình đã lưu'), findsOneWidget);

    // Switch to Yêu thích tab
    await tester.tap(find.text('Yêu thích'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có lịch trình yêu thích'), findsOneWidget);
  });

  testWidgets('Renders items and allows removing saved item without Undo', (tester) async {
    fakeRepo.savedResponse = [
      createSummary(id: 101, title: 'Lịch trình Đà Nẵng'),
    ];
    fakeRepo.favoriteResponse = [];

    await tester.pumpWidget(buildTestScreen());
    await tester.pumpAndSettle();

    expect(find.text('Lịch trình Đà Nẵng'), findsOneWidget);
    expect(find.byType(ItineraryCard), findsOneWidget);

    // Tap bookmark action on card to remove
    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();

    expect(fakeRepo.removeSavedCallCount, equals(1));
    expect(find.text('Đã bỏ lưu lịch trình'), findsOneWidget);
    // Verify NO Undo button exists
    expect(find.text('Hoàn tác'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('Renders items and allows removing favorite item without Undo', (tester) async {
    fakeRepo.savedResponse = [];
    fakeRepo.favoriteResponse = [
      createSummary(id: 202, title: 'Lịch trình Phú Quốc'),
    ];

    await tester.pumpWidget(buildTestScreen());
    await tester.pumpAndSettle();

    // Switch to Yêu thích tab
    await tester.tap(find.text('Yêu thích'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch trình Phú Quốc'), findsOneWidget);
    expect(find.byType(ItineraryCard), findsOneWidget);

    // Tap favorite action on card to remove
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(fakeRepo.removeFavoriteCallCount, equals(1));
    expect(find.text('Đã bỏ yêu thích lịch trình'), findsOneWidget);
    // Verify NO Undo button exists
    expect(find.text('Hoàn tác'), findsNothing);
    expect(find.text('Undo'), findsNothing);
  });
}

