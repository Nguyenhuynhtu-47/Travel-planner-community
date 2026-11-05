import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/location/data/location_repository.dart';
import 'package:mobile/features/location/data/models/location_search_result.dart';

void main() {
  group('LocationSearchResult Model Tests', () {
    test('fromJson parses standard backend JSON response correctly', () {
      final json = {
        'placeId': 'osm_way_12345',
        'name': 'Hồ Xuân Hương',
        'formattedAddress': 'Phường 1, TP. Đà Lạt, Lâm Đồng, Việt Nam',
        'latitude': 11.9404,
        'longitude': 108.4378,
        'category': 'tourism',
        'provider': 'LOCATION_IQ',
      };

      final result = LocationSearchResult.fromJson(json);

      expect(result.placeId, 'osm_way_12345');
      expect(result.name, 'Hồ Xuân Hương');
      expect(
        result.formattedAddress,
        'Phường 1, TP. Đà Lạt, Lâm Đồng, Việt Nam',
      );
      expect(result.latitude, 11.9404);
      expect(result.longitude, 108.4378);
      expect(result.category, 'tourism');
      expect(result.provider, 'LOCATION_IQ');
      expect(result.hasCoordinates, isTrue);
    });

    test('fromJson supports fallback alternative keys (place_id, display_name, lat, lon)', () {
      final json = {
        'place_id': 'loc_9988',
        'name': 'Chợ Đà Lạt',
        'display_name': 'Nguyễn Thị Minh Khai, Phường 1, Đà Lạt',
        'lat': '11.9421',
        'lon': '108.4362',
      };

      final result = LocationSearchResult.fromJson(json);

      expect(result.placeId, 'loc_9988');
      expect(result.name, 'Chợ Đà Lạt');
      expect(result.formattedAddress, 'Nguyễn Thị Minh Khai, Phường 1, Đà Lạt');
      expect(result.latitude, 11.9421);
      expect(result.longitude, 108.4362);
      expect(result.hasCoordinates, isTrue);
    });

    test('hasCoordinates returns false when latitude or longitude is null', () {
      const resultNoLat = LocationSearchResult(
        placeId: 'id_1',
        name: 'Địa điểm không lat',
        formattedAddress: 'Địa chỉ',
        latitude: null,
        longitude: 108.4,
      );
      expect(resultNoLat.hasCoordinates, isFalse);

      const resultNoLon = LocationSearchResult(
        placeId: 'id_2',
        name: 'Địa điểm không lon',
        formattedAddress: 'Địa chỉ',
        latitude: 11.9,
        longitude: null,
      );
      expect(resultNoLon.hasCoordinates, isFalse);
    });

    test('toJson serializes correctly', () {
      const result = LocationSearchResult(
        placeId: 'p_10',
        name: 'Quảng trường Lâm Viên',
        formattedAddress: 'Trần Quốc Toản, Phường 10, Đà Lạt',
        latitude: 11.9366,
        longitude: 108.4452,
        category: 'tourism',
        provider: 'LOCATION_IQ',
      );

      final json = result.toJson();

      expect(json['placeId'], 'p_10');
      expect(json['name'], 'Quảng trường Lâm Viên');
      expect(json['latitude'], 11.9366);
      expect(json['longitude'], 108.4452);
      expect(json['category'], 'tourism');
      expect(json['provider'], 'LOCATION_IQ');
    });

    test('copyWith, equality, hashCode, and toString work as expected', () {
      const original = LocationSearchResult(
        placeId: 'p_1',
        name: 'Tiệm Cà Phê Tùng',
        formattedAddress: '06 Khu Hòa Bình',
        latitude: 11.9404,
        longitude: 108.4385,
      );

      final copy = original.copyWith(name: 'Cà phê Tùng Mới');
      expect(copy.name, 'Cà phê Tùng Mới');
      expect(copy.placeId, original.placeId);
      expect(copy.formattedAddress, original.formattedAddress);

      const identicalItem = LocationSearchResult(
        placeId: 'p_1',
        name: 'Tiệm Cà Phê Tùng',
        formattedAddress: '06 Khu Hòa Bình',
        latitude: 11.9404,
        longitude: 108.4385,
      );

      expect(original, equals(identicalItem));
      expect(original.hashCode, equals(identicalItem.hashCode));
      expect(original.toString(), contains('Tiệm Cà Phê Tùng'));
    });
  });

  group('LocationRepository Tests', () {
    test('searchLocations returns empty list immediately if query is shorter than 2 chars', () async {
      var clientCalled = false;
      final mockClient = MockClient((request) async {
        clientCalled = true;
        return http.Response('[]', 200);
      });

      final repo = LocationRepository(apiClient: ApiClient(client: mockClient));

      final resultEmpty = await repo.searchLocations('');
      final resultShort = await repo.searchLocations('a');
      final resultWhitespace = await repo.searchLocations('   ');

      expect(resultEmpty, isEmpty);
      expect(resultShort, isEmpty);
      expect(resultWhitespace, isEmpty);
      expect(
        clientCalled,
        isFalse,
        reason: 'Must not call API for queries shorter than 2 characters',
      );
    });

    test(
      'searchLocations sends correct query parameters and parses list',
      () async {
        Uri? capturedUri;
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          capturedHeaders = request.headers;

          final mockResponse = [
            {
              'placeId': 'osm_1',
              'name': 'Dinh 1 Đà Lạt',
              'formattedAddress': 'Trần Quang Diệu, Phường 10, Đà Lạt',
              'latitude': 11.9288,
              'longitude': 108.4688,
              'category': 'tourism',
              'provider': 'LOCATION_IQ',
            },
            {
              'placeId': 'osm_2',
              'name': 'Dinh 3 Đà Lạt',
              'formattedAddress': 'Triệu Việt Vương, Phường 4, Đà Lạt',
              'latitude': 11.9299,
              'longitude': 108.4300,
              'category': 'tourism',
              'provider': 'LOCATION_IQ',
            },
          ];

          return http.Response(
            jsonEncode(mockResponse),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = LocationRepository(
          apiClient: ApiClient(client: mockClient),
        );

        final results = await repo.searchLocations(
          '  Dinh Bảo Đại  ',
          limit: 5,
          latitude: 11.94,
          longitude: 108.44,
          token: 'test_token_123',
        );

        expect(results.length, 2);
        expect(results[0].name, 'Dinh 1 Đà Lạt');
        expect(results[1].name, 'Dinh 3 Đà Lạt');

        expect(capturedUri?.path, '/api/locations/search');
        expect(capturedUri?.queryParameters['query'], 'Dinh Bảo Đại');
        expect(capturedUri?.queryParameters['limit'], '5');
        expect(capturedUri?.queryParameters['latitude'], '11.94');
        expect(capturedUri?.queryParameters['longitude'], '108.44');
        expect(capturedHeaders?['authorization'], 'Bearer test_token_123');
      },
    );

    test(
      'searchNearby sends viewport, category and radius then parses results',
      () async {
        Uri? capturedUri;
        final mockClient = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode([
              {
                'placeId': 'osm_node_12',
                'name': 'Bảo tàng',
                'formattedAddress': 'Hà Nội',
                'latitude': 21.0,
                'longitude': 105.8,
                'provider': 'LOCATION_IQ',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final repo = LocationRepository(
          apiClient: ApiClient(client: mockClient),
        );

        final results = await repo.searchNearby(
          latitude: 21.0,
          longitude: 105.8,
          category: 'ATTRACTION',
          radiusMeters: 3000,
          token: 'token',
        );

        expect(results.single.name, 'Bảo tàng');
        expect(capturedUri?.path, '/api/locations/nearby');
        expect(capturedUri?.queryParameters['latitude'], '21.0');
        expect(capturedUri?.queryParameters['longitude'], '105.8');
        expect(capturedUri?.queryParameters['category'], 'ATTRACTION');
        expect(capturedUri?.queryParameters['radiusMeters'], '3000');
      },
    );

    test(
      'searchLocations throws ApiException on HTTP 429 Too Many Requests',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Bạn đã gửi quá nhiều yêu cầu'}),
            429,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = LocationRepository(
          apiClient: ApiClient(client: mockClient),
        );

        expect(
          () => repo.searchLocations('Hà Nội'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429),
          ),
        );
      },
    );

    test('reverseGeocode sends coordinates and parses response', () async {
      Uri? capturedUri;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;

        final mockResponse = {
          'placeId': 'rev_99',
          'name': 'Vườn Hoa Thành Phố',
          'formattedAddress': 'Bà Huyện Thanh Quan, Phường 8, Đà Lạt',
          'latitude': 11.9511,
          'longitude': 108.4522,
          'category': 'leisure',
          'provider': 'LOCATION_IQ',
        };

        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = LocationRepository(apiClient: ApiClient(client: mockClient));

      final result = await repo.reverseGeocode(11.9511, 108.4522);

      expect(result, isNotNull);
      expect(result?.name, 'Vườn Hoa Thành Phố');
      expect(capturedUri?.path, '/api/locations/reverse-geocode');
      expect(capturedUri?.queryParameters['latitude'], '11.9511');
      expect(capturedUri?.queryParameters['longitude'], '108.4522');
    });

    test('reverseGeocode returns null when backend returns 404 Not Found (no address at coordinates)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Không tìm thấy thông tin địa điểm tại tọa độ đã chọn',
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = LocationRepository(apiClient: ApiClient(client: mockClient));

      final result = await repo.reverseGeocode(0.0, 0.0);
      expect(result, isNull, reason: 'Must return null gracefully on 404');
    });

    test('reverseGeocode rethrows ApiException on non-404 errors (e.g. 429 rate limit)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Rate limit exceeded'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = LocationRepository(apiClient: ApiClient(client: mockClient));

      expect(
        () => repo.reverseGeocode(11.9, 108.4),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });
  });
}
