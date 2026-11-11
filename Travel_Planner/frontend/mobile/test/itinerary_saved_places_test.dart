import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_place.dart';
import 'package:mobile/features/itinerary/data/models/place_summary.dart';

void main() {
  group('Phase 4 - Itinerary-Scoped Saved Places Models', () {
    test('ItineraryPlace fromJson and toJson serialization roundtrip', () {
      final json = {
        'id': 10,
        'itineraryId': 42,
        'place': {
          'placeId': 101,
          'name': 'Chợ Bến Thành',
          'address': 'Quận 1, TP. Hồ Chí Minh',
          'category': 'SHOPPING',
          'latitude': 10.7725,
          'longitude': 106.698,
          'status': 'ACTIVE',
        },
        'savedAt': '2026-09-20T10:00:00.000Z',
      };

      final itineraryPlace = ItineraryPlace.fromJson(json);

      expect(itineraryPlace.id, 10);
      expect(itineraryPlace.itineraryId, 42);
      expect(itineraryPlace.place.placeId, 101);
      expect(itineraryPlace.place.name, 'Chợ Bến Thành');
      expect(itineraryPlace.place.address, 'Quận 1, TP. Hồ Chí Minh');
      expect(itineraryPlace.place.category, 'SHOPPING');
      expect(itineraryPlace.place.latitude, 10.7725);
      expect(itineraryPlace.place.longitude, 106.698);
      expect(itineraryPlace.savedAt, isNotNull);

      final serialized = itineraryPlace.toJson();
      expect(serialized['id'], 10);
      expect(serialized['itineraryId'], 42);
      expect(serialized['place']['placeId'], 101);
      expect(serialized['place']['name'], 'Chợ Bến Thành');
    });

    test('ItineraryPlace handles missing or null fields gracefully', () {
      final json = {
        'id': 1,
        'itineraryId': 5,
        'place': {
          'placeId': 20,
          'name': 'Khu bảo tồn thiên nhiên',
        },
      };

      final itineraryPlace = ItineraryPlace.fromJson(json);

      expect(itineraryPlace.id, 1);
      expect(itineraryPlace.itineraryId, 5);
      expect(itineraryPlace.place.placeId, 20);
      expect(itineraryPlace.place.name, 'Khu bảo tồn thiên nhiên');
      expect(itineraryPlace.place.address, isNull);
      expect(itineraryPlace.savedAt, isNull);
    });
  });
}

