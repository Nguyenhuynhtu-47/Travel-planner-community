import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/explore/data/models/itinerary_summary.dart';
import 'package:mobile/features/explore/presentation/widgets/itinerary_card.dart';
import 'package:mobile/features/explore/presentation/widgets/search_bar_pill.dart';
import 'package:mobile/shared/widgets/app_empty_state.dart';
import 'package:mobile/shared/widgets/app_primary_button.dart';
import 'package:mobile/shared/widgets/app_text_field.dart';

void main() {
  group('Animation Enhancements - Shared Widgets', () {
    testWidgets(
      'AppPrimaryButton crossfades between text and loading indicator',
      (tester) async {
        bool isLoading = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return AppPrimaryButton(
                    text: 'Đăng nhập',
                    isLoading: isLoading,
                    onPressed: () => setState(() => isLoading = true),
                  );
                },
              ),
            ),
          ),
        );

        // Initially renders text label
        expect(find.text('Đăng nhập'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Tap to trigger loading
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump(); // Start animation frame

        // Mid-transition pump
        await tester.pump(const Duration(milliseconds: 75));

        // Settle transition
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('AppPrimaryButton respects disableAnimations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AppPrimaryButton(
                text: 'Lưu',
                isLoading: true,
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppTextField animates password visibility toggle', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'secret123');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Mật khẩu',
              controller: controller,
              isPassword: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);
    });

    testWidgets('AppEmptyState renders icon with scale-in animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'Không có dữ liệu',
              message: 'Danh sách đang trống',
              icon: Icons.inbox_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Không có dữ liệu'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(Transform), findsWidgets);
    });
  });

  group('Animation Enhancements - Explore & Card Widgets', () {
    testWidgets('SearchBarPill animates clear button and filter badge', (
      tester,
    ) async {
      final controller = TextEditingController();
      int filterCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SearchBarPill(
                  controller: controller,
                  activeFilterCount: filterCount,
                  onFilterTap: () => setState(() => filterCount = 2),
                );
              },
            ),
          ),
        ),
      );

      // Initially no clear button and no filter badge
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.text('2'), findsNothing);

      // Type text -> clear button appears with animation
      controller.text = 'Đà Lạt';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap filter -> badge appears with scale transition
      await tester.tap(find.byTooltip('Bộ lọc'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets(
      'ItineraryCard handles favorite tap with micro-scale interaction',
      (tester) async {
        bool favoriteTapped = false;

        final summary = ItinerarySummary(
          itineraryId: 101,
          title: 'Chuyến đi Đà Lạt mộng mơ',
          description: '3 ngày 2 đêm',
          coverImage: '',
          location: 'Đà Lạt',
          totalDays: 3,
          budget: 2500000,
          averageRating: 4.8,
          ratingCount: 12,
          favoriteCount: 5,
          viewCount: 150,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ItineraryCard(
                  itinerary: summary,
                  onFavoriteTap: () => favoriteTapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

        // Tap favorite heart button
        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(favoriteTapped, isTrue);
      },
    );
  });
}
