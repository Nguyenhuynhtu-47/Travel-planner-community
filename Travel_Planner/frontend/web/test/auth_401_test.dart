import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/auth/data/auth_storage.dart';

import 'package:travel_planner_web/features/auth/data/auth_repository.dart';

String _createMockJwt({required int expSeconds}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'webadmin', 'exp': expSeconds})))
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

void main() {
  group('Web ApiClient 401 Handling Tests', () {
    setUp(() {
      ApiClient.globalOnUnauthorized = null;
      ApiClient.resetThrottle();
    });

    tearDown(() {
      ApiClient.globalOnUnauthorized = null;
      ApiClient.resetThrottle();
    });

    test('ApiClient triggers onUnauthorized callback when receiving 401', () async {
      int unauthorizedCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 401, 'message': 'Token expired'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        onUnauthorized: () {
          unauthorizedCount++;
        },
      );

      try {
        await client.get('/api/test');
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(401));
      }

      expect(unauthorizedCount, equals(1));
    });

    test('ApiClient does NOT trigger onUnauthorized on 200, 400, 403, 500', () async {
      int unauthorizedCount = 0;

      final testCases = [
        {'status': 200, 'body': {'data': 'ok'}},
        {'status': 400, 'body': {'message': 'Bad Request'}},
        {'status': 403, 'body': {'message': 'Forbidden'}},
        {'status': 500, 'body': {'message': 'Server Error'}},
      ];

      for (final tc in testCases) {
        ApiClient.resetThrottle();
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode(tc['body']),
            tc['status'] as int,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          client: mockClient,
          onUnauthorized: () {
            unauthorizedCount++;
          },
        );

        if ((tc['status'] as int) >= 200 && (tc['status'] as int) < 300) {
          await client.get('/api/test');
        } else {
          try {
            await client.get('/api/test');
          } catch (_) {}
        }
      }

      expect(unauthorizedCount, equals(0));
    });

    test('ApiClient throttles repeated 401 notifications within throttle duration', () async {
      int unauthorizedCount = 0;
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 401, 'message': 'Token expired'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        onUnauthorized: () {
          unauthorizedCount++;
        },
      );

      for (int i = 0; i < 3; i++) {
        try {
          await client.get('/api/test');
        } catch (_) {}
      }

      expect(unauthorizedCount, equals(1));
    });

    test('ApiClient triggers globalOnUnauthorized when instance callback is null', () async {
      int globalCount = 0;
      ApiClient.globalOnUnauthorized = () {
        globalCount++;
      };

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Unauthorized'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(client: mockClient);

      try {
        await client.post('/api/test', body: {});
      } catch (_) {}

      expect(globalCount, equals(1));
    });
  });

  group('Web AuthNotifier Session Expiry and Verification Tests', () {
    test('handleSessionExpired clears credentials and marks unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'sample_web_token',
        'auth_user': jsonEncode({'username': 'webadmin', 'role': 'ADMIN'}),
      });

      final storage = AuthStorage();
      final notifier = AuthNotifier(storage: storage);

      expect(await storage.getToken(), equals('sample_web_token'));

      await notifier.handleSessionExpired();

      expect(notifier.token, isNull);
      expect(notifier.currentUser, isNull);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(notifier.isAuthenticated, isFalse);
      expect(await storage.getToken(), isNull);
    });

    test('checkAuthStatus with valid token and /api/auth/me 200 updates profile and stays authenticated', () async {
      final validToken = _createMockJwt(
        expSeconds: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': validToken,
        'auth_user': jsonEncode({'username': 'oldadmin', 'fullName': 'Old Admin'}),
      });

      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/auth/me'));
        expect(request.headers['Authorization'], equals('Bearer $validToken'));
        return http.Response(
          jsonEncode({
            'id': 1,
            'username': 'webadmin',
            'email': 'admin@example.com',
            'fullName': 'Admin Verified',
            'role': 'ADMIN',
            'status': 'ACTIVE',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final storage = AuthStorage();
      final repository = AuthRepository(apiClient: ApiClient(client: mockClient));
      final notifier = AuthNotifier(repository: repository, storage: storage);

      await notifier.checkAuthStatus();

      expect(notifier.status, equals(AuthStatus.authenticated));
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.token, equals(validToken));
      expect(notifier.currentUser?['fullName'], equals('Admin Verified'));
      expect(notifier.currentUser?['role'], equals('ADMIN'));
    });

    test('checkAuthStatus with valid token and /api/auth/me 401 clears storage and marks unauthenticated', () async {
      final validToken = _createMockJwt(
        expSeconds: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': validToken,
        'auth_user': jsonEncode({'username': 'webadmin'}),
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Session expired or revoked'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final storage = AuthStorage();
      final repository = AuthRepository(apiClient: ApiClient(client: mockClient));
      final notifier = AuthNotifier(repository: repository, storage: storage);

      await notifier.checkAuthStatus();

      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.token, isNull);
      expect(notifier.currentUser, isNull);
      expect(await storage.getToken(), isNull);
    });

    test('checkAuthStatus with valid token and server 500 preserves cached session', () async {
      final validToken = _createMockJwt(
        expSeconds: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': validToken,
        'auth_user': jsonEncode({'username': 'webadmin', 'fullName': 'Cached Admin'}),
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Internal Server Error'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final storage = AuthStorage();
      final repository = AuthRepository(apiClient: ApiClient(client: mockClient));
      final notifier = AuthNotifier(repository: repository, storage: storage);

      await notifier.checkAuthStatus();

      expect(notifier.status, equals(AuthStatus.authenticated));
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.token, equals(validToken));
      expect(notifier.currentUser?['fullName'], equals('Cached Admin'));
      expect(await storage.getToken(), equals(validToken));
    });

    test('checkAuthStatus with locally expired token purges storage without calling backend', () async {
      final expiredToken = _createMockJwt(expSeconds: 1000);
      bool backendCalled = false;

      SharedPreferences.setMockInitialValues({
        'auth_token': expiredToken,
        'auth_user': jsonEncode({'username': 'webadmin'}),
      });

      final mockClient = MockClient((request) async {
        backendCalled = true;
        return http.Response('{}', 200);
      });

      final storage = AuthStorage();
      final repository = AuthRepository(apiClient: ApiClient(client: mockClient));
      final notifier = AuthNotifier(repository: repository, storage: storage);

      await notifier.checkAuthStatus();

      expect(backendCalled, isFalse);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.token, isNull);
      expect(await storage.getToken(), isNull);
    });
  });
}
