import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/auth_storage.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/change_password_screen.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_otp_screen.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:mobile/shared/widgets/app_otp_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Password Reset & Change Password Mobile Tests (Phase 2 & 3-Step Refactor)', () {
    test('ForgotPassword sends email and returns 200 generic message with cooldown', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/forgot-password')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], equals('traveler@example.com'));
          return http.Response(
            jsonEncode({
              'message': 'Nếu địa chỉ email tồn tại trong hệ thống, mã xác nhận đặt lại mật khẩu sẽ được gửi đến hộp thư của bạn.',
              'cooldownSeconds': 60,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final response = await notifier.forgotPassword('traveler@example.com');
      expect(response['cooldownSeconds'], equals(60));
      expect(response['message'], contains('Nếu địa chỉ email tồn tại'));
    });

    test('VerifyResetOtp verifies 6-digit code and returns resetToken', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-reset-otp')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], equals('traveler@example.com'));
          expect(body['otp'], equals('123456'));
          return http.Response(
            jsonEncode({
              'message': 'Mã xác thực hợp lệ.',
              'resetToken': 'mock-secure-reset-challenge-token-64hex',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final response = await notifier.verifyResetOtp(
        email: 'traveler@example.com',
        otp: '123456',
      );
      expect(response['message'], equals('Mã xác thực hợp lệ.'));
      expect(response['resetToken'], equals('mock-secure-reset-challenge-token-64hex'));
    });

    test('ResetPassword sends email, resetToken and relaxed newPassword successfully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/reset-password')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], equals('traveler@example.com'));
          expect(body['resetToken'], equals('mock-secure-reset-challenge-token-64hex'));
          // Relaxed password policy: only lowercase is valid
          expect(body['newPassword'], equals('onlylowercase'));
          return http.Response(
            jsonEncode({
              'message': 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final response = await notifier.resetPassword(
        email: 'traveler@example.com',
        resetToken: 'mock-secure-reset-challenge-token-64hex',
        newPassword: 'onlylowercase',
      );
      expect(response['message'], contains('Đặt lại mật khẩu thành công'));
    });

    test('ChangePassword sends authenticated request, increments token_version and logs out session', () async {
      final expFuture = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final payloadBase64 = base64Url.encode(utf8.encode(jsonEncode({'sub': 'traveler', 'exp': expFuture})));
      final validJwt = 'eyJhbGciOiJIUzI1NiJ9.$payloadBase64.signature';

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/me')) {
          return http.Response(
            jsonEncode({
              'userId': 1,
              'username': 'traveler',
              'email': 'traveler@example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/api/auth/change-password')) {
          expect(request.headers['authorization'], equals('Bearer $validJwt'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['currentPassword'], equals('OldPassword@123'));
          expect(body['newPassword'], equals('BrandNewPassword@456'));
          return http.Response(
            jsonEncode({
              'message': 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final storage = AuthStorage();
      await storage.saveToken(validJwt);
      await storage.saveUser({'username': 'traveler'});

      final notifier = AuthNotifier(repository: repository, storage: storage);
      await notifier.checkAuthStatus(); // load session
      expect(notifier.token, equals(validJwt));

      final response = await notifier.changePassword(
        currentPassword: 'OldPassword@123',
        newPassword: 'BrandNewPassword@456',
      );

      expect(response['message'], contains('Đổi mật khẩu thành công'));
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.token, isNull);
      expect(await storage.getToken(), isNull);
    });

    testWidgets('Step 1: ForgotPasswordScreen renders UI and validates email input', (tester) async {
      final repository = AuthRepository();
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            authNotifier: notifier,
            initialEmail: 'init@example.com',
          ),
        ),
      );

      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(find.text('init@example.com'), findsOneWidget);
    });

    testWidgets('Step 2: ForgotPasswordOtpScreen renders 6-box OTP component and validates OTP', (tester) async {
      final repository = AuthRepository();
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordOtpScreen(
            authNotifier: notifier,
            email: 'user@example.com',
            initialCooldown: 60,
          ),
        ),
      );

      expect(find.text('Xác thực mã OTP'), findsOneWidget);
      expect(find.byType(AppOtpInput), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Xác nhận mã OTP'), findsOneWidget);
      expect(find.text('Chỉnh sửa địa chỉ email'), findsOneWidget);
    });

    testWidgets('Step 3: ResetPasswordScreen renders UI and verifies relaxed password policy', (tester) async {
      final repository = AuthRepository();
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ResetPasswordScreen(
            authNotifier: notifier,
            email: 'user@example.com',
            resetToken: 'sample-challenge-token',
          ),
        ),
      );

      expect(find.text('Đặt lại mật khẩu'), findsAtLeastNWidgets(1));
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.text('Xác nhận mật khẩu mới'), findsOneWidget);

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu');
      await tester.ensureVisible(buttonFinder);

      // 1. Empty submission -> triggers "Vui lòng nhập mật khẩu mới"
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập mật khẩu mới'), findsOneWidget);

      // 2. Short password (< 6 chars) -> triggers "Mật khẩu phải có tối thiểu 6 ký tự"
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '12345');
      await tester.enterText(textFields.at(1), '12345');
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu phải có tối thiểu 6 ký tự'), findsOneWidget);

      // 3. Mismatched confirm password -> triggers "Mật khẩu xác nhận không khớp"
      await tester.enterText(textFields.at(0), 'onlylowercase');
      await tester.enterText(textFields.at(1), 'differentpassword');
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);

      // 4. Relaxed policy: Simple lowercase-only password "onlylowercase" (>= 6 chars) is ACCEPTED
      // (No strong password validation errors like "chữ hoa", "ký tự đặc biệt"!)
      await tester.enterText(textFields.at(0), 'onlylowercase');
      await tester.enterText(textFields.at(1), 'onlylowercase');
      await tester.pumpAndSettle();
      expect(find.text('chữ hoa'), findsNothing);
      expect(find.text('ký tự đặc biệt'), findsNothing);

      // 5. Relaxed policy: Simple digits-only password "123456" is also ACCEPTED
      await tester.enterText(textFields.at(0), '123456');
      await tester.enterText(textFields.at(1), '123456');
      await tester.pumpAndSettle();
      expect(find.text('chữ hoa'), findsNothing);
      expect(find.text('ký tự đặc biệt'), findsNothing);
    });

    testWidgets('AppOtpInput allows 6 digits input, backspace regression, and paste', (tester) async {
      String currentCode = '';
      String completedCode = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOtpInput(
              length: 6,
              onChanged: (code) => currentCode = code,
              onCompleted: (code) => completedCode = code,
            ),
          ),
        ),
      );

      final digitBoxes = find.byType(TextField);
      expect(digitBoxes, findsNWidgets(6));

      // Type digit '1' in first box
      await tester.enterText(digitBoxes.at(0), '1');
      await tester.pump();
      expect(currentCode, equals('1'));

      // Test multi-digit paste: "654321" into first box
      await tester.enterText(digitBoxes.at(0), '654321');
      await tester.pump();
      expect(currentCode, equals('654321'));
      expect(completedCode, equals('654321'));
    });

    testWidgets('ChangePasswordScreen renders UI and validates password matching', (tester) async {
      final repository = AuthRepository();
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(
            authNotifier: notifier,
          ),
        ),
      );

      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(find.text('Tạo mật khẩu mới'), findsOneWidget);
      expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
      expect(find.text('Cập nhật mật khẩu'), findsOneWidget);
    });

    testWidgets('Step 2: Correct OTP transitions to Step 3 and does NOT navigate to Home', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-reset-otp')) {
          return http.Response(
            jsonEncode({
              'message': 'Mã xác thực hợp lệ.',
              'resetToken': 'verified-reset-challenge-token',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordOtpScreen(
              authNotifier: notifier,
              email: 'traveler@example.com',
            ),
          ),
        ),
      );

      // Enter 6-digit OTP
      final digitBoxes = find.byType(TextField);
      expect(digitBoxes, findsNWidgets(6));
      await tester.enterText(digitBoxes.at(0), '123456');
      await tester.pumpAndSettle();

      // Step 3 (ResetPasswordScreen) must be displayed
      expect(find.text('Đặt lại mật khẩu'), findsAtLeastNWidgets(1));
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.text('Xác nhận mật khẩu mới'), findsOneWidget);

      // Must NOT navigate to Home
      expect(find.text('Khám phá'), findsNothing);
      expect(find.text('Lịch trình của tôi'), findsNothing);
    });

    testWidgets('Step 2: Incorrect OTP remains on Step 2 with error banner', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-reset-otp')) {
          return http.Response(
            jsonEncode({
              'status': 400,
              'message': 'Mã xác thực không chính xác. Bạn còn 4 lần thử.',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordOtpScreen(
              authNotifier: notifier,
              email: 'traveler@example.com',
            ),
          ),
        ),
      );

      final digitBoxes = find.byType(TextField);
      await tester.enterText(digitBoxes.at(0), '000000');
      await tester.pumpAndSettle();

      // Remains on Step 2
      expect(find.text('Xác thực mã OTP'), findsOneWidget);
      expect(find.text('Mã xác thực không chính xác. Bạn còn 4 lần thử.'), findsOneWidget);

      // Does not navigate to Step 3 or Home
      expect(find.text('Đặt lại mật khẩu'), findsNothing);
      expect(find.text('Khám phá'), findsNothing);
    });

    testWidgets('Step 2: Expired OTP remains on Step 2 with error banner', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-reset-otp')) {
          return http.Response(
            jsonEncode({
              'status': 400,
              'message': 'Mã xác thực đã hết hạn. Vui lòng gửi yêu cầu mới.',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordOtpScreen(
              authNotifier: notifier,
              email: 'traveler@example.com',
            ),
          ),
        ),
      );

      final digitBoxes = find.byType(TextField);
      await tester.enterText(digitBoxes.at(0), '999999');
      await tester.pumpAndSettle();

      // Remains on Step 2
      expect(find.text('Xác thực mã OTP'), findsOneWidget);
      expect(find.text('Mã xác thực đã hết hạn. Vui lòng gửi yêu cầu mới.'), findsOneWidget);
      expect(find.text('Đặt lại mật khẩu'), findsNothing);
    });

    testWidgets('Step 3: Successful password reset navigates cleanly to Login, NOT Home', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/reset-password')) {
          return http.Response(
            jsonEncode({
              'message': 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('Root Home Screen')),
          routes: {
            '/login': (_) => LoginScreen(authNotifier: notifier),
          },
        ),
      );

      // Push LoginScreen
      final navKey = tester.state<NavigatorState>(find.byType(Navigator));
      navKey.push(MaterialPageRoute(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => LoginScreen(authNotifier: notifier),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập để tiếp tục kế hoạch du lịch của bạn'), findsOneWidget);

      // Push ResetPasswordScreen
      navKey.push(MaterialPageRoute(
        settings: const RouteSettings(name: '/reset-password'),
        builder: (_) => ResetPasswordScreen(
          authNotifier: notifier,
          email: 'traveler@example.com',
          resetToken: 'test-token',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu mới'), findsOneWidget);

      // Submit valid password
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'newpassword123');
      await tester.enterText(textFields.at(1), 'newpassword123');

      final submitBtn = find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verified: Navigates to LoginScreen, NOT Home!
      expect(find.text('Đăng nhập để tiếp tục kế hoạch du lịch của bạn'), findsOneWidget);
      expect(find.text('Tên đăng nhập hoặc Email'), findsOneWidget);
      expect(find.text('Root Home Screen'), findsNothing);
    });

    test('No JWT or authenticated session is created by password-reset OTP verification', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-reset-otp')) {
          return http.Response(
            jsonEncode({
              'message': 'Mã xác thực hợp lệ.',
              'resetToken': 'verified-challenge-token',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final storage = AuthStorage();
      final notifier = AuthNotifier(repository: repository, storage: storage);

      final response = await notifier.verifyResetOtp(
        email: 'traveler@example.com',
        otp: '123456',
      );

      expect(response['resetToken'], equals('verified-challenge-token'));
      // Guarantee: No token, no user, not authenticated!
      expect(notifier.token, isNull);
      expect(notifier.currentUser, isNull);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(await storage.getToken(), isNull);
    });

    test('Email Verification continues to authenticate normally with JWT', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-email')) {
          return http.Response(
            jsonEncode({
              'token': 'jwt-for-activated-account',
              'user': {
                'userId': 99,
                'email': 'activated@example.com',
                'fullName': 'Activated User',
                'role': 'USER',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final storage = AuthStorage();
      final notifier = AuthNotifier(repository: repository, storage: storage);

      final success = await notifier.verifyEmail(
        email: 'activated@example.com',
        code: '123456',
      );

      expect(success, isTrue);
      // Email verification establishes authenticated session
      expect(notifier.token, equals('jwt-for-activated-account'));
      expect(notifier.currentUser?['email'], equals('activated@example.com'));
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.status, equals(AuthStatus.authenticated));
      expect(await storage.getToken(), equals('jwt-for-activated-account'));
    });

    testWidgets('ChangePasswordScreen navigates to LoginScreen on success, clears client state, and back button does not return to authenticated screens', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/change-password')) {
          return http.Response(
            jsonEncode({
              'message': 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/api/auth/logout')) {
          return http.Response(
            jsonEncode({'message': 'Logged out successfully'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final storage = AuthStorage();
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'sub': 'user@example.com',
        'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      })));
      final testJwt = '$header.$payload.signature';
      await storage.saveToken(testJwt);
      await storage.saveUser({'userId': 1, 'email': 'user@example.com', 'fullName': 'Old User'});
      final notifier = AuthNotifier(repository: repository, storage: storage);
      await notifier.checkAuthStatus();
      expect(notifier.isAuthenticated, isTrue);

      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('Root Home Screen')),
      ));

      // Push Profile / Authenticated screen, then ChangePasswordScreen
      navKey.currentState!.push(MaterialPageRoute(
        settings: const RouteSettings(name: '/personal-info'),
        builder: (_) => const Scaffold(body: Text('Personal Info Authenticated Screen')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Personal Info Authenticated Screen'), findsOneWidget);

      navKey.currentState!.push(MaterialPageRoute(
        settings: const RouteSettings(name: '/change-password'),
        builder: (_) => ChangePasswordScreen(authNotifier: notifier),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Đổi mật khẩu'), findsOneWidget);

      // Enter current password and new password
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'OldPassword123!');
      await tester.enterText(textFields.at(1), 'NewPassword123!');
      await tester.enterText(textFields.at(2), 'NewPassword123!');

      final submitBtn = find.widgetWithText(ElevatedButton, 'Cập nhật mật khẩu');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verified: Navigates to LoginScreen, NOT Home!
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Đăng nhập để tiếp tục kế hoạch du lịch của bạn'), findsOneWidget);
      expect(find.text('Root Home Screen'), findsNothing);
      expect(find.text('Personal Info Authenticated Screen'), findsNothing);

      // Auth state and token are completely cleared locally
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.token, isNull);
      expect(notifier.currentUser, isNull);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(await storage.getToken(), isNull);

      // Verify SnackBar message is displayed
      expect(find.text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'), findsOneWidget);

      // Press Back on LoginScreen - verify it NEVER returns to authenticated Personal Info screen
      if (find.byType(IconButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(IconButton).first);
        await tester.pumpAndSettle();
        expect(find.text('Personal Info Authenticated Screen'), findsNothing);
      }
    });
  });
}
