import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders logo, fields and action buttons', (WidgetTester tester) async {
    final notifier = AuthNotifier();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: notifier),
      ),
    );

    await tester.pump();

    expect(find.text('Travel Planner'), findsOneWidget);
    expect(find.text('Tên đăng nhập hoặc Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
  });
}
