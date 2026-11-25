import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Web LoginScreen renders portal title, inputs and buttons', (WidgetTester tester) async {
    final notifier = AuthNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: notifier),
      ),
    );

    await tester.pump();

    expect(find.text('Travel Planner Portal'), findsOneWidget);
    expect(find.text('Đăng nhập hệ thống'), findsOneWidget);
    expect(find.text('ADMIN PORTAL'), findsOneWidget);
    expect(find.text('Tên đăng nhập hoặc Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Tên đăng nhập hoặc Email')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(
      tester.widget<Text>(find.text('Mật khẩu')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web LoginScreen renders 45:55 wave split desktop layout without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notifier = AuthNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: notifier),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chào mừng đến với'), findsOneWidget);
    expect(find.text('Travel Planner'), findsOneWidget);
    expect(find.text('Travel Planner Portal'), findsOneWidget);
    expect(find.text('ADMIN PORTAL'), findsOneWidget);
    expect(find.text('Đăng nhập hệ thống'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);

    // Short desktop height remains scrollable with zero vertical overflow
    tester.view.physicalSize = const Size(1280, 620);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web LoginScreen renders vertical wave header layout cleanly on narrow viewports', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final notifier = AuthNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: notifier),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Travel Planner'), findsOneWidget);
    expect(find.text('Travel Planner Portal'), findsOneWidget);
    expect(find.text('Đăng nhập hệ thống'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);
  });
}
