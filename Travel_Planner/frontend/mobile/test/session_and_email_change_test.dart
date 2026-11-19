import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/auth_storage.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/change_email_screen.dart';
import 'package:mobile/features/auth/presentation/screens/device_sessions_screen.dart';

String _createMockJwt() {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'testuser', 'exp': exp})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

class MockAuthRepository extends AuthRepository {
  bool logoutCalled = false;
  bool revokeSessionCalled = false;
  String? revokedSessionId;
  bool revokeOtherSessionsCalled = false;
  bool requestEmailChangeCalled = false;
  bool verifyEmailChangeCalled = false;
  String? requestedNewEmail;
  String? verifiedOtp;

  @override
  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    return {
      'userId': 1,
      'username': 'testuser',
      'email': 'old@example.com',
      'role': 'USER',
      'emailVerified': true,
    };
  }

  List<Map<String, dynamic>> mockSessions = [
    {
      'sessionId': 'session-1',
      'deviceInfo': 'Pixel 8 Pro (Android)',
      'ipAddress': '192.168.1.10',
      'status': 'ACTIVE',
      'createdAt': '2026-11-18T00:00:00Z',
      'lastActiveAt': '2026-11-18T01:00:00Z',
      'isCurrentSession': true,
    },
    {
      'sessionId': 'session-2',
      'deviceInfo': 'Chrome on Windows',
      'ipAddress': '192.168.1.20',
      'status': 'ACTIVE',
      'createdAt': '2026-11-17T12:00:00Z',
      'lastActiveAt': '2026-11-17T15:00:00Z',
      'isCurrentSession': false,
    },
  ];

  @override
  Future<void> logout(String token) async {
    logoutCalled = true;
  }

  @override
  Future<List<Map<String, dynamic>>> getSessions(String token) async {
    return mockSessions;
  }

  @override
  Future<void> revokeSession({
    required String token,
    required String sessionId,
  }) async {
    revokeSessionCalled = true;
    revokedSessionId = sessionId;
  }

  @override
  Future<int> revokeOtherSessions(String token) async {
    revokeOtherSessionsCalled = true;
    return 1;
  }

  @override
  Future<Map<String, dynamic>> requestEmailChange({
    required String token,
    required String newEmail,
    String? password,
  }) async {
    requestEmailChangeCalled = true;
    requestedNewEmail = newEmail;
    return {
      'message': 'Mã xác thực đã được gửi đến địa chỉ email mới.',
      'newEmail': newEmail,
    };
  }

  @override
  Future<Map<String, dynamic>> verifyEmailChange({
    required String token,
    required String newEmail,
    required String otp,
  }) async {
    verifyEmailChangeCalled = true;
    verifiedOtp = otp;
    return {
      'message': 'Đổi địa chỉ email thành công.',
      'newEmail': newEmail,
    };
  }
}

class MockAuthStorage extends AuthStorage {
  String? token;
  Map<String, dynamic>? user;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveToken(String t) async {
    token = t;
  }

  @override
  Future<Map<String, dynamic>?> getUser() async => user;

  @override
  Future<void> saveUser(Map<String, dynamic> u) async {
    user = u;
  }

  @override
  Future<void> clear() async {
    token = null;
    user = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session & Device Management Mobile Tests', () {
    late MockAuthRepository mockRepository;
    late MockAuthStorage mockStorage;
    late AuthNotifier authNotifier;
    late String testJwt;

    setUp(() {
      testJwt = _createMockJwt();
      mockRepository = MockAuthRepository();
      mockStorage = MockAuthStorage();
      mockStorage.token = testJwt;
      mockStorage.user = {
        'userId': 1,
        'username': 'testuser',
        'email': 'old@example.com',
        'role': 'USER',
        'emailVerified': true,
      };
      authNotifier = AuthNotifier(
        repository: mockRepository,
        storage: mockStorage,
      );
    });

    testWidgets('DeviceSessionsScreen renders sessions and highlights current device', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSessionsScreen(authNotifier: authNotifier),
        ),
      );

      // Initially loading, pump until sessions load
      await tester.pumpAndSettle();

      // Verify sessions rendered
      expect(find.text('Pixel 8 Pro (Android)'), findsOneWidget);
      expect(find.text('Chrome on Windows'), findsOneWidget);
      expect(find.text('Thiết bị này'), findsOneWidget);
      expect(find.text('Đăng xuất thiết bị này'), findsOneWidget);
      expect(find.text('Đăng xuất tất cả thiết bị khác'), findsOneWidget);
    });

    testWidgets('DeviceSessionsScreen revoking single device prompts dialog and calls API', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSessionsScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Đăng xuất thiết bị này" on session 2
      await tester.tap(find.text('Đăng xuất thiết bị này'));
      await tester.pumpAndSettle();

      // Confirmation dialog shows
      expect(find.text('Đăng xuất thiết bị'), findsOneWidget);
      expect(find.text('Bạn có chắc chắn muốn đăng xuất khỏi thiết bị "Chrome on Windows"?'), findsOneWidget);

      // Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
      await tester.pumpAndSettle();

      expect(mockRepository.revokeSessionCalled, isTrue);
      expect(mockRepository.revokedSessionId, equals('session-2'));
    });

    testWidgets('DeviceSessionsScreen revoking all other devices prompts dialog and calls API', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSessionsScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Đăng xuất tất cả thiết bị khác"
      await tester.tap(find.text('Đăng xuất tất cả thiết bị khác'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng xuất tất cả thiết bị khác'), findsWidgets);

      // Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất tất cả'));
      await tester.pumpAndSettle();

      expect(mockRepository.revokeOtherSessionsCalled, isTrue);
    });

    test('AuthNotifier logout calls server-side endpoint before clearing local storage', () async {
      await authNotifier.checkAuthStatus();
      expect(authNotifier.token, equals(testJwt));

      await authNotifier.logout();

      expect(mockRepository.logoutCalled, isTrue);
      expect(authNotifier.token, isNull);
      expect(authNotifier.isAuthenticated, isFalse);
    });
  });

  group('Email Change Mobile Tests', () {
    late MockAuthRepository mockRepository;
    late MockAuthStorage mockStorage;
    late AuthNotifier authNotifier;
    late String testJwt;

    setUp(() {
      testJwt = _createMockJwt();
      mockRepository = MockAuthRepository();
      mockStorage = MockAuthStorage();
      mockStorage.token = testJwt;
      mockStorage.user = {
        'userId': 1,
        'username': 'testuser',
        'email': 'old@example.com',
        'role': 'USER',
        'emailVerified': true,
      };
      authNotifier = AuthNotifier(
        repository: mockRepository,
        storage: mockStorage,
      );
    });

    testWidgets('ChangeEmailScreen Step 1 validates inputs and transitions to Step 2 on success', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeEmailScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Step 1 fields
      expect(find.text('Mật khẩu hiện tại *'), findsOneWidget);
      expect(find.text('Địa chỉ email mới *'), findsOneWidget);

      // Try submitting empty
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập mật khẩu hiện tại'), findsOneWidget);
      expect(find.text('Email mới không được để trống'), findsOneWidget);

      // Fill valid inputs
      await tester.enterText(find.byType(TextFormField).first, 'Password123!');
      await tester.enterText(find.byType(TextFormField).last, 'newemail@example.com');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      expect(mockRepository.requestEmailChangeCalled, isTrue);
      expect(mockRepository.requestedNewEmail, equals('newemail@example.com'));

      // Now on Step 2
      expect(find.text('newemail@example.com'), findsOneWidget);
      expect(find.text('Xác nhận đổi email'), findsOneWidget);
    });

    testWidgets('ChangeEmailScreen Step 2 submits OTP and updates currentUser email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeEmailScreen(authNotifier: authNotifier),
        ),
      );
      await tester.pumpAndSettle();

      // Complete Step 1
      await tester.enterText(find.byType(TextFormField).first, 'Password123!');
      await tester.enterText(find.byType(TextFormField).last, 'newemail@example.com');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Step 2: enter 6 digit OTP (triggers auto-submit when all 6 digits entered)
      final otpFields = find.byType(TextField);
      expect(otpFields, findsNWidgets(6));
      for (int i = 0; i < 6; i++) {
        await tester.enterText(otpFields.at(i), '${i + 1}');
      }
      await tester.pumpAndSettle();

      expect(mockRepository.verifyEmailChangeCalled, isTrue);
      expect(mockRepository.verifiedOtp, equals('123456'));
      expect(authNotifier.currentUser?['email'], equals('newemail@example.com'));
    });
  });
}
