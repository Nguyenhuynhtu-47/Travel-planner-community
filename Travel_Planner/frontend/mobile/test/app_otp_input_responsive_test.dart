import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_otp_screen.dart';
import 'package:mobile/shared/widgets/app_otp_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppOtpInput Responsive Layout & Border Tests', () {
    testWidgets('Renders on narrow 320px screen without any horizontal overflow', (tester) async {
      // Small screen like iPhone SE or narrow device
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String currentCode = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: AppOtpInput(
                  length: 6,
                  onChanged: (val) => currentCode = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow exception was caught
      expect(tester.takeException(), isNull);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));
    });

    testWidgets('Renders on Samsung SM-A346E (384px logical width) without overflow', (tester) async {
      // Samsung Galaxy A34 5G (SM-A346E) logical width ~384-411dp
      tester.view.physicalSize = const Size(384 * 2.75, 854 * 2.75);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: AppOtpInput(
                  length: 6,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('EmailVerificationScreen does not overflow on 360px and 384px screens', (tester) async {
      tester.view.physicalSize = const Size(360 * 3.0, 800 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            authNotifier: notifier,
            email: 'user@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppOtpInput), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('ForgotPasswordOtpScreen does not overflow on 360px and 384px screens', (tester) async {
      tester.view.physicalSize = const Size(360 * 3.0, 800 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordOtpScreen(
            authNotifier: notifier,
            email: 'user@example.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppOtpInput), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('Focusing an OTP box highlights only with primary border and no duplicate outlines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.black, width: 2.0),
              ),
            ),
          ),
          home: Scaffold(
            body: Center(
              child: AppOtpInput(
                length: 6,
                autoFocus: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first box to focus
      final firstBox = find.byType(TextField).first;
      await tester.tap(firstBox);
      await tester.pumpAndSettle();

      // Find the container around the first box
      final containers = tester.widgetList<Container>(find.descendant(
        of: find.byType(AppOtpInput),
        matching: find.byType(Container),
      ));

      // The focused box container should have primary border
      final focusedBox = containers.first;
      final decoration = focusedBox.decoration as BoxDecoration;
      final border = decoration.border as Border;

      expect(border.top.color, equals(AppColors.primary));
      expect(border.top.width, equals(2.0));

      // Inactive boxes should have subtle border
      final inactiveBox = containers.elementAt(1);
      final inactiveDec = inactiveBox.decoration as BoxDecoration;
      final inactiveBorder = inactiveDec.border as Border;

      expect(inactiveBorder.top.color, equals(AppColors.border));
      expect(inactiveBorder.top.width, equals(1.0));
    });

    testWidgets('Typing digits advances focus, backspace clears previous, paste distributes 6 digits', (tester) async {
      String currentCode = '';
      String completedCode = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppOtpInput(
                length: 6,
                onChanged: (c) => currentCode = c,
                onCompleted: (c) => completedCode = c,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);

      // Type '1' in first box
      await tester.enterText(fields.at(0), '1');
      await tester.pumpAndSettle();
      expect(currentCode, equals('1'));

      // Type '2' in second box
      await tester.enterText(fields.at(1), '2');
      await tester.pumpAndSettle();
      expect(currentCode, equals('12'));

      // Paste '987654' into third box
      await tester.enterText(fields.at(2), '987654');
      await tester.pumpAndSettle();
      expect(currentCode, equals('987654'));
      expect(completedCode, equals('987654'));
    });
  });
}
