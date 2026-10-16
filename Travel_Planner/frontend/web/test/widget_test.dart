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
    expect(find.text('Tên đăng nhập hoặc Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
  });
}
