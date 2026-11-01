import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';

void main() {
  test(
    'uploads an image as authenticated multipart data and returns secure URL',
    () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/media/images');
        expect(request.headers['authorization'], 'Bearer test-jwt');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="file"; filename="avatar.jpg"'));

        return http.Response(
          jsonEncode({
            'secureUrl': 'https://res.cloudinary.com/example/avatar.jpg',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repository = ProfileRepository(
        apiClient: ApiClient(client: mockClient),
      );
      final secureUrl = await repository.uploadImage(
        'test-jwt',
        bytes: [1, 2, 3, 4],
        filename: 'avatar.jpg',
      );

      expect(requestCount, 1);
      expect(secureUrl, 'https://res.cloudinary.com/example/avatar.jpg');
    },
  );
}
