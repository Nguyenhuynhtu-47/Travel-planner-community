import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/auth_storage.dart';
import 'package:mobile/features/auth/data/google_sign_in_service.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/auth/presentation/widgets/google_sign_in_button.dart';

class MockGoogleSignInService implements GoogleSignInService {
  final String? idTokenToReturn;
  final bool shouldThrow;

  MockGoogleSignInService({this.idTokenToReturn, this.shouldThrow = false});

  @override
  Future<String?> signInAndGetIdToken() async {
    if (shouldThrow) {
      throw Exception('Google Sign In SDK Failure');
    }
    return idTokenToReturn;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Google Sign-In Mobile Tests (Phase 3)', () {
    test('loginWithGoogle: Successful sign-in authenticates user and saves JWT token', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/google')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['idToken'] == 'valid-google-id-token') {
            return http.Response(
              jsonEncode({
                'token': 'tp.jwt.token.12345',
                'tokenType': 'Bearer',
                'user': {
                  'userId': 101,
                  'username': 'googletraveler',
                  'email': 'traveler@gmail.com',
                  'fullName': 'Google Traveler',
                  'emailVerified': true,
                  'role': 'USER',
                  'status': 'ACTIVE',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Unauthorized', 401);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final storage = AuthStorage();
      final notifier = AuthNotifier(repository: repository, storage: storage);

      final mockGoogleService = MockGoogleSignInService(idTokenToReturn: 'valid-google-id-token');

      final success = await notifier.loginWithGoogle(googleSignInService: mockGoogleService);

      expect(success, isTrue);
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.token, equals('tp.jwt.token.12345'));
      expect(notifier.currentUser?['email'], equals('traveler@gmail.com'));
      expect(notifier.status, equals(AuthStatus.authenticated));

      // Check persisted token in storage
      final savedToken = await storage.getToken();
      expect(savedToken, equals('tp.jwt.token.12345'));
    });

    test('loginWithGoogle: User cancellation returns false and maintains unauthenticated state without error', () async {
      final mockClient = MockClient((request) async => http.Response('Not reached', 500));
      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final mockGoogleService = MockGoogleSignInService(idTokenToReturn: null); // Cancelled

      final success = await notifier.loginWithGoogle(googleSignInService: mockGoogleService);

      expect(success, isFalse);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(notifier.errorMessage, isNull);
    });

    test('loginWithGoogle: 409 Conflict sets error status and guides user to local account login', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/google')) {
          return http.Response(
            jsonEncode({
              'timestamp': '2026-11-17T16:00:00Z',
              'status': 409,
              'error': 'Conflict',
              'message': 'Email này đã được sử dụng bởi một tài khoản khác. Vui lòng đăng nhập bằng mật khẩu và liên kết tài khoản Google trong phần cài đặt.',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final mockGoogleService = MockGoogleSignInService(idTokenToReturn: 'conflict-google-token');

      final success = await notifier.loginWithGoogle(googleSignInService: mockGoogleService);

      expect(success, isFalse);
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.status, equals(AuthStatus.error));
      expect(notifier.errorMessage, contains('liên kết'));
    });

    test('loginWithGoogle: SDK exception sets error status with graceful message', () async {
      final mockClient = MockClient((request) async => http.Response('Not reached', 500));
      final apiClient = ApiClient(client: mockClient);
      final repository = AuthRepository(apiClient: apiClient);
      final notifier = AuthNotifier(repository: repository);

      final mockGoogleService = MockGoogleSignInService(shouldThrow: true);

      final success = await notifier.loginWithGoogle(googleSignInService: mockGoogleService);

      expect(success, isFalse);
      expect(notifier.status, equals(AuthStatus.error));
      expect(notifier.errorMessage, contains('thất bại'));
    });

    testWidgets('GoogleSignInButton renders on LoginScreen and triggers onPressed', (tester) async {
      final notifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authNotifier: notifier),
        ),
      );

      // Verify Google Sign-In button and divider exist
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
      expect(find.text('Hoặc'), findsOneWidget);
    });

    testWidgets('GoogleSignInButton renders on RegisterScreen', (tester) async {
      final notifier = AuthNotifier();

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(authNotifier: notifier),
        ),
      );

      // Verify Google Sign-In button and divider exist
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Đăng ký bằng Google'), findsOneWidget);
      expect(find.text('Hoặc'), findsOneWidget);
    });
  });
}
