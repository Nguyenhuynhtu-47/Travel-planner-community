import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/itinerary/data/helpers/location_activity_mapper.dart';
import 'package:mobile/features/location/data/models/location_search_result.dart';

void main() {
  group('Phase 6A.2 - LocationActivityMapper Unit Tests', () {
    test('maps Internal Place correctly: sets canonicalPlaceId, forces null coordinates', () {
      const internalPlace = LocationSearchResult(
        placeId: 'place_42',
        name: 'Dinh Độc Lập',
        formattedAddress: '135 Nam Kỳ Khởi Nghĩa, Quận 1',
        provider: 'SYSTEM',
        type: 'place',
        latitude: 10.7770,
        longitude: 106.6953,
      );

      final request = LocationActivityMapper.toCreateRequest(
        location: internalPlace,
        name: 'Tham quan Dinh Độc Lập',
        description: 'Chụp ảnh và tìm hiểu lịch sử',
        startTime: '09:00',
        endTime: '11:30',
        cost: 65000,
      );

      expect(request.name, 'Tham quan Dinh Độc Lập');
      expect(request.description, 'Chụp ảnh và tìm hiểu lịch sử');
      expect(request.canonicalPlaceId, 42);
      expect(request.destinationId, isNull);
      // Critical invariant check: coordinates MUST be null to prevent HTTP 400
      expect(request.latitude, isNull);
      expect(request.longitude, isNull);
      expect(request.locationName, 'Dinh Độc Lập');
      expect(request.locationAddress, '135 Nam Kỳ Khởi Nghĩa, Quận 1');
      expect(request.placeId, 'place_42');
      expect(request.locationProvider, 'PLACE_CATALOG');
      expect(request.startTime, '09:00');
      expect(request.endTime, '11:30');
      expect(request.cost, 65000);

      // Verify serialization output
      final json = request.toJson();
      expect(json['canonicalPlaceId'], 42);
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      expect(json['startTime'], '09:00:00');
      expect(json['endTime'], '11:30:00');
    });

    test('maps External POI correctly: null canonicalPlaceId, preserves coordinates and provider', () {
      const externalPoi = LocationSearchResult(
        placeId: 'tomtom_poi_888',
        name: 'Highlands Coffee - Hàm Nghi',
        formattedAddress: '68 Hàm Nghi, Bến Nghé, Quận 1',
        provider: 'TOMTOM',
        type: 'poi',
        latitude: 10.7712,
        longitude: 106.7025,
      );

      final request = LocationActivityMapper.toCreateRequest(
        location: externalPoi,
        name: '', // empty name falls back to location.name
        startTime: '14:00',
        endTime: '15:00',
        cost: 45000,
      );

      expect(request.name, 'Highlands Coffee - Hàm Nghi');
      expect(request.canonicalPlaceId, isNull);
      expect(request.latitude, 10.7712);
      expect(request.longitude, 106.7025);
      expect(request.locationName, 'Highlands Coffee - Hàm Nghi');
      expect(request.locationAddress, '68 Hàm Nghi, Bến Nghé, Quận 1');
      expect(request.placeId, 'tomtom_poi_888');
      expect(request.locationProvider, 'TOMTOM');

      // Verify serialization output
      final json = request.toJson();
      expect(json.containsKey('canonicalPlaceId'), isFalse);
      expect(json['latitude'], 10.7712);
      expect(json['longitude'], 106.7025);
      expect(json['placeId'], 'tomtom_poi_888');
      expect(json['locationProvider'], 'TOMTOM');
    });

    test('maps Manual Pin correctly: null canonicalPlaceId, coordinates preserved, provider MANUAL_PIN', () {
      const manualPin = LocationSearchResult(
        placeId: '',
        name: 'Vị trí đã ghim',
        formattedAddress: '10.76000, 106.68000',
        provider: 'MANUAL_PIN',
        latitude: 10.7600,
        longitude: 106.6800,
      );

      final request = LocationActivityMapper.toCreateRequest(
        location: manualPin,
        name: 'Gặp bạn bè tại điểm hẹn',
      );

      expect(request.name, 'Gặp bạn bè tại điểm hẹn');
      expect(request.canonicalPlaceId, isNull);
      expect(request.latitude, 10.7600);
      expect(request.longitude, 106.6800);
      expect(request.locationName, 'Vị trí đã ghim');
      expect(request.locationAddress, '10.76000, 106.68000');
      expect(request.placeId, isNull);
      expect(request.locationProvider, 'MANUAL_PIN');
    });

    test('throws ArgumentError when attempting to schedule an Administrative Area', () {
      const adminArea = LocationSearchResult(
        placeId: 'admin_79',
        name: 'Thành phố Hồ Chí Minh',
        formattedAddress: 'Việt Nam',
        provider: 'SYSTEM',
        type: 'administrative',
        category: 'boundary',
        isLocalityFallback: true,
        latitude: 10.7769,
        longitude: 106.7009,
      );

      expect(
        () => LocationActivityMapper.toCreateRequest(
          location: adminArea,
          name: 'Đi dạo',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

