import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/shared/widgets/admin_data_table.dart';
import 'package:travel_planner_web/shared/widgets/admin_dialog.dart';
import 'package:travel_planner_web/shared/widgets/admin_page_header.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';
import 'package:travel_planner_web/shared/widgets/admin_toolbar.dart';
import 'package:travel_planner_web/shared/widgets/app_primary_button.dart';
import 'package:travel_planner_web/shared/widgets/app_text_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise Design Tokens & WCAG Contrast Verification', () {
    test('AppColors verifies Rausch Primary brand palette tokens', () {
      expect(AppColors.primary, const Color(0xFFFF385C)); // Rausch
      expect(AppColors.primaryDark, const Color(0xFFE00B41)); // Primary Active
      expect(AppColors.primaryLight, const Color(0xFFFFF0F2)); // Primary Light tint
      expect(AppColors.accent, const Color(0xFFFF385C));

      expect(AppColors.background, const Color(0xFFFFFFFF));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.border, const Color(0xFFE2E8F0));
      expect(AppColors.borderStrong, const Color(0xFFCBD5E1));

      expect(AppColors.textPrimary, const Color(0xFF0F172A));
      expect(AppColors.textSecondary, const Color(0xFF334155));
      expect(AppColors.textMuted, const Color(0xFF64748B));
    });

    test('WCAG 2.1 AA Contrast calculations for textPrimary and Primary button', () {
      // Relative luminance formula helper
      double luminance(Color c) => c.computeLuminance();
      double contrastRatio(Color c1, Color c2) {
        final l1 = luminance(c1);
        final l2 = luminance(c2);
        final brighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (brighter + 0.05) / (darker + 0.05);
      }

      // Ink on White
      final inkContrast = contrastRatio(AppColors.textPrimary, Colors.white);
      expect(inkContrast > 15.0, isTrue, reason: 'Ink on White must exceed 15:1 for WCAG AA');

      // Body on White
      final bodyContrast = contrastRatio(AppColors.textSecondary, Colors.white);
      expect(bodyContrast > 7.0, isTrue, reason: 'Body text must exceed 7:1 for WCAG AA');

      // Accessible token on White
      final primaryAccessibleContrast = contrastRatio(Colors.white, AppColors.primaryAccessible);
      expect(primaryAccessibleContrast >= 4.5, isTrue,
          reason: 'Primary accessible text on white must satisfy 4.5:1 threshold');
    });

    test('Disciplined Geometry tokens follow Swiss Minimalist 4px grid', () {
      expect(AppRadius.none, 0.0);
      expect(AppRadius.xs, 2.0);
      expect(AppRadius.badge, 4.0);
      expect(AppRadius.sm, 4.0);
      expect(AppRadius.input, 6.0);
      expect(AppRadius.button, 6.0);
      expect(AppRadius.sidebarItem, 6.0);
      expect(AppRadius.md, 6.0);
      expect(AppRadius.card, 8.0);
      expect(AppRadius.dialog, 8.0);
      expect(AppRadius.table, 8.0);
      expect(AppRadius.lg, 8.0);

      expect(AppHeights.header, 52.0);
      expect(AppHeights.toolbar, 46.0);
      expect(AppHeights.tableHeader, 38.0);
      expect(AppHeights.tableRow, 44.0);
      expect(AppHeights.buttonStandard, 36.0);
    });
  });

  group('AdminPageHeader Widget Tests', () {
    testWidgets('Renders title, subtitle and action buttons cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPageHeader(
              title: 'Quản lý Bài viết',
              subtitle: 'Kiểm duyệt bài đăng cộng đồng vi phạm tiêu chuẩn.',
              actions: [
                ElevatedButton(onPressed: () {}, child: const Text('Tác vụ mới')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Quản lý Bài viết'), findsOneWidget);
      expect(find.text('Kiểm duyệt bài đăng cộng đồng vi phạm tiêu chuẩn.'), findsOneWidget);
      expect(find.text('Tác vụ mới'), findsOneWidget);
    });
  });

  group('AdminToolbar Widget Tests', () {
    testWidgets('Renders search field, dropdown filters and actions in Row', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminToolbar(
              searchField: const TextField(decoration: InputDecoration(hintText: 'Tìm kiếm...')),
              filters: const [Text('Bộ lọc trạng thái')],
              actions: [
                OutlinedButton(onPressed: () {}, child: const Text('Làm mới')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Bộ lọc trạng thái'), findsOneWidget);
      expect(find.text('Làm mới'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('AdminStatusBadge Widget Tests', () {
    testWidgets('Renders semantic labels and styles across all status domains', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AdminStatusBadge(status: 'ACTIVE'),
                AdminStatusBadge(status: 'PENDING'),
                AdminStatusBadge(status: 'HIDDEN'),
                AdminStatusBadge(status: 'DELETED'),
                AdminStatusBadge(status: 'RESOLVED'),
                AdminStatusBadge(status: 'UNATTACHED'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Chờ xử lý'), findsOneWidget);
      expect(find.text('Đã ẩn'), findsOneWidget);
      expect(find.text('Đã xóa'), findsOneWidget);
      expect(find.text('Đã xử lý'), findsOneWidget);
      expect(find.text('Chưa gán'), findsOneWidget);
    });
  });

  group('AdminDataTable Widget Tests', () {
    testWidgets('Renders header, data rows, and pagination bar correctly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int changedPage = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDataTable(
              columns: [
                AdminDataColumn.text('ID'),
                AdminDataColumn.text('TÊN TÀI KHOẢN'),
                AdminDataColumn.text('TRẠNG THÁI'),
              ],
              rows: const [
                AdminDataRow(cells: [
                  Text('#101'),
                  Text('user_one'),
                  AdminStatusBadge(status: 'ACTIVE'),
                ]),
                AdminDataRow(cells: [
                  Text('#102'),
                  Text('user_two'),
                  AdminStatusBadge(status: 'PENDING'),
                ]),
              ],
              currentPage: 0,
              totalPages: 5,
              totalElements: 100,
              pageSize: 20,
              onPageChanged: (newPage) => changedPage = newPage,
            ),
          ),
        ),
      );

      expect(find.text('ID'), findsOneWidget);
      expect(find.text('TÊN TÀI KHOẢN'), findsOneWidget);
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('user_one'), findsOneWidget);
      expect(find.text('#102'), findsOneWidget);
      expect(find.text('user_two'), findsOneWidget);

      // Pagination elements
      expect(find.text('Hiển thị 1 - 2 trong số 100 bản ghi'), findsOneWidget);
      expect(find.text('Trang 1 / 5'), findsOneWidget);

      // Tap on next page icon
      await tester.tap(find.byTooltip('Trang sau'));
      await tester.pump();
      expect(changedPage, 1);
    });

    testWidgets('Renders loading and empty states cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDataTable(
              isLoading: true,
              columns: [],
              rows: [],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDataTable(
              isLoading: false,
              columns: [],
              rows: [],
              emptyMessage: 'Không có báo cáo nào tồn đọng.',
            ),
          ),
        ),
      );

      expect(find.text('Không có báo cáo nào tồn đọng.'), findsOneWidget);
    });
  });

  group('AdminDialog Widget Tests', () {
    testWidgets('Renders 3-part modal layout with title, content and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AdminDialog.show<void>(
                      context: context,
                      title: 'Chi tiết Báo cáo #10',
                      titleBadge: const AdminStatusBadge(status: 'PENDING'),
                      content: const Text('Nội dung vi phạm tiêu chuẩn cộng đồng'),
                      actions: [
                        TextButton(onPressed: () {}, child: const Text('Đóng')),
                        ElevatedButton(onPressed: () {}, child: const Text('Xử lý vi phạm')),
                      ],
                    );
                  },
                  child: const Text('Mở Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Báo cáo #10'), findsOneWidget);
      expect(find.text('Chờ xử lý'), findsOneWidget);
      expect(find.text('Nội dung vi phạm tiêu chuẩn cộng đồng'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
      expect(find.text('Xử lý vi phạm'), findsOneWidget);
    });
  });

  group('AppPrimaryButton & AppTextField Tests', () {
    testWidgets('AppPrimaryButton displays text, icon, and handles loading spinner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppPrimaryButton(text: 'Lưu thay đổi', icon: Icons.save, onPressed: () {}),
                AppPrimaryButton(text: 'Đang tải', isLoading: true, onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Lưu thay đổi'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppTextField renders stacked label, hint, and text input', (tester) async {
      final ctrl = TextEditingController(text: 'Khách sạn Caravelle');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Tên địa điểm',
              hint: 'Nhập tên địa điểm...',
              controller: ctrl,
            ),
          ),
        ),
      );

      expect(find.text('Tên địa điểm'), findsOneWidget);
      expect(find.text('Khách sạn Caravelle'), findsOneWidget);
    });
  });
}
