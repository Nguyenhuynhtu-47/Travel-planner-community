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
import 'package:mobile/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:mobile/shared/widgets/app_otp_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Email Verification Mobile Tests (Phase 1)', () {
    test('Register returns requiresVerification and keeps user unauthenticated until OTP verified', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/register')) {
          return http.Response(
            jsonEncode({
              'message': 'Đăng ký thành công. Vui lòng kiểm tra email để nhận mã xác thực.',
              'email': 'newtraveler@example.com',
              'requiresVerification': true,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final success = await notifier.register(
        username: 'newtraveler',
        email: 'newtraveler@example.com',
        password: 'Password123!',
        fullName: 'New Traveler',
      );

      expect(success, isTrue);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
    });

    test('VerifyEmail succeeds with valid OTP and authenticates user with token', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-email')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['code'] == '123456') {
            return http.Response(
              jsonEncode({
                'token': 'valid-jwt-token-after-verification',
                'tokenType': 'Bearer',
                'user': {
                  'userId': 99,
                  'username': 'verified_user',
                  'email': 'verify@example.com',
                  'emailVerified': true,
                  'role': 'USER',
                  'status': 'ACTIVE',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response(
              jsonEncode({
                'status': 400,
                'message': 'Mã xác thực không chính xác',
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final storage = AuthStorage();
      final notifier = AuthNotifier(repository: repository, storage: storage);

      final success = await notifier.verifyEmail(
        email: 'verify@example.com',
        code: '123456',
      );

      expect(success, isTrue);
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.token, equals('valid-jwt-token-after-verification'));
      expect(notifier.currentUser?['emailVerified'], isTrue);
    });

    test('VerifyEmail fails with invalid OTP and records error message', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/verify-email')) {
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

      final success = await notifier.verifyEmail(
        email: 'verify@example.com',
        code: '000000',
      );

      expect(success, isFalse);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.errorMessage, contains('Mã xác thực không chính xác'));
    });

    test('ResendVerification calls endpoint and returns success message', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/resend-verification')) {
          return http.Response(
            jsonEncode({
              'message': 'Mã xác thực mới đã được gửi vào email của bạn.',
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

      final message = await notifier.resendVerification(
        email: 'resend@example.com',
      );

      expect(message, contains('Mã xác thực mới'));
    });

    testWidgets('EmailVerificationScreen renders email and 6-digit input correctly', (tester) async {
      final notifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            authNotifier: notifier,
            email: 'test@example.com',
          ),
        ),
      );

      expect(find.text('Xác thực tài khoản'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('test@example.com')),
        findsOneWidget,
      );
      expect(find.text('Kích hoạt tài khoản'), findsOneWidget);
      expect(find.byType(AppOtpInput), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });
  });
}
