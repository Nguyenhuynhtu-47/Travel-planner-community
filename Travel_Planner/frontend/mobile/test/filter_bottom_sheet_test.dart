import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/explore/presentation/explore_notifier.dart';
import 'package:mobile/features/explore/presentation/widgets/filter_bottom_sheet.dart';

void main() {
  group('FilterBottomSheet UI and Checkmark Tests', () {
    Widget buildTestWidget({
      ExploreFilter? initialFilter,
      String initialSort = 'createdAt,desc',
      Function(ExploreFilter, String)? onApply,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                FilterBottomSheet.show(
                  context,
                  currentFilter: initialFilter ?? const ExploreFilter(),
                  currentSort: initialSort,
                  onApply: onApply ?? (_, __) {},
                );
              },
              child: const Text('Open Filters'),
            ),
          ),
        ),
      );
    }

    testWidgets('Selected filter chips do not show leading checkmark icon', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          initialFilter: const ExploreFilter(
            theme: 'Nghỉ dưỡng',
            minRating: 4.0,
          ),
          initialSort: 'rating,desc',
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Filters'));
      await tester.pumpAndSettle();

      // Find all ChoiceChips
      final choiceChips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      expect(choiceChips.isNotEmpty, isTrue);

      // Verify every single ChoiceChip has showCheckmark == false
      for (final chip in choiceChips) {
        expect(
          chip.showCheckmark,
          isFalse,
          reason: 'ChoiceChip for "${chip.label}" should have showCheckmark set to false',
        );
      }

      // Verify selected state styling is preserved
      final ratingSortChip = choiceChips.firstWhere(
        (c) => c.selected && (c.label is Text && (c.label as Text).data == 'Đánh giá cao nhất'),
      );
      expect(ratingSortChip.selected, isTrue);
      expect(ratingSortChip.selectedColor, equals(AppColors.textPrimary));

      // Verify no check icon is rendered inside ChoiceChips
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('Selecting and deselecting filter options works properly without checkmarks', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ExploreFilter? appliedFilter;
      String? appliedSort;

      await tester.pumpWidget(
        buildTestWidget(
          initialFilter: const ExploreFilter(),
          initialSort: 'createdAt,desc',
          onApply: (filter, sort) {
            appliedFilter = filter;
            appliedSort = sort;
          },
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Filters'));
      await tester.pumpAndSettle();

      // Tap 'Đánh giá cao nhất' sort option
      await tester.ensureVisible(find.text('Đánh giá cao nhất'));
      await tester.tap(find.text('Đánh giá cao nhất'));
      await tester.pumpAndSettle();

      // Scroll to and tap 'Ẩm thực' theme option
      await tester.ensureVisible(find.text('Ẩm thực'));
      await tester.tap(find.text('Ẩm thực'));
      await tester.pumpAndSettle();

      // Scroll to and tap '4.5+' rating option
      await tester.ensureVisible(find.text('4.5+'));
      await tester.tap(find.text('4.5+'));
      await tester.pumpAndSettle();

      // Verify all ChoiceChips still have showCheckmark == false and no check icons exist
      final updatedChips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      for (final chip in updatedChips) {
        expect(chip.showCheckmark, isFalse);
      }
      expect(find.byIcon(Icons.check), findsNothing);

      // Deselect 'Ẩm thực' by tapping it again
      await tester.ensureVisible(find.text('Ẩm thực'));
      await tester.tap(find.text('Ẩm thực'));
      await tester.pumpAndSettle();

      // Select 'Phượt' theme option
      await tester.ensureVisible(find.text('Phượt'));
      await tester.tap(find.text('Phượt'));
      await tester.pumpAndSettle();

      // Tap 'Tất cả' rating option to clear rating filter
      await tester.ensureVisible(find.text('Tất cả'));
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();

      // Tap 'Áp dụng' button
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      // Verify applied filters
      expect(appliedSort, equals('rating,desc'));
      expect(appliedFilter, isNotNull);
      expect(appliedFilter!.theme, equals('Phượt'));
      expect(appliedFilter!.minRating, isNull);
    });

    testWidgets('Reset button clears selections back to defaults', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          initialFilter: const ExploreFilter(
            theme: 'Nghỉ dưỡng',
            minRating: 4.0,
            location: 'Đà Lạt',
          ),
          initialSort: 'budget,asc',
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Filters'));
      await tester.pumpAndSettle();

      // Verify 'Nghỉ dưỡng' is currently selected
      await tester.ensureVisible(find.text('Nghỉ dưỡng'));
      ChoiceChip themeChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Nghỉ dưỡng'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(themeChip.selected, isTrue);

      // Tap 'Đặt lại' button
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();

      // Verify 'Nghỉ dưỡng' is no longer selected
      await tester.ensureVisible(find.text('Nghỉ dưỡng'));
      themeChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Nghỉ dưỡng'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(themeChip.selected, isFalse);

      // Verify sort reset to 'createdAt,desc' ('Mới nhất')
      await tester.ensureVisible(find.text('Mới nhất'));
      final sortChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Mới nhất'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(sortChip.selected, isTrue);
      expect(sortChip.showCheckmark, isFalse);

      // Verify 'Tất cả' rating option is selected
      await tester.ensureVisible(find.text('Tất cả'));
      final allRatingChip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Tất cả'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(allRatingChip.selected, isTrue);
      expect(allRatingChip.showCheckmark, isFalse);
    });
  });
}
