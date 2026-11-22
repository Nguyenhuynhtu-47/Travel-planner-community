import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/place_category_helper.dart';
import 'package:mobile/features/itinerary/data/models/destination_summary.dart';
import 'package:mobile/features/itinerary/data/models/itinerary_place.dart';
import 'package:mobile/features/itinerary/data/models/place_summary.dart';

void main() {
  group('PlaceCategoryHelper', () {
    test('localizes canonical PlaceCategory enums accurately', () {
      expect(PlaceCategoryHelper.localize('ATTRACTION'), 'Điểm tham quan');
      expect(PlaceCategoryHelper.localize('RESTAURANT'), 'Nhà hàng');
      expect(PlaceCategoryHelper.localize('HOTEL'), 'Khách sạn');
      expect(PlaceCategoryHelper.localize('CAFE'), 'Quán cà phê');
      expect(PlaceCategoryHelper.localize('ENTERTAINMENT'), 'Giải trí');
      expect(PlaceCategoryHelper.localize('SHOPPING'), 'Cửa hàng');
      expect(PlaceCategoryHelper.localize('OTHER'), 'Khác');
    });

    test('is case-insensitive and trims whitespace', () {
      expect(PlaceCategoryHelper.localize('  attraction  '), 'Điểm tham quan');
      expect(PlaceCategoryHelper.localize('Restaurant'), 'Nhà hàng');
      expect(PlaceCategoryHelper.localize('cafe'), 'Quán cà phê');
      expect(PlaceCategoryHelper.localize('HOTEL '), 'Khách sạn');
    });

    test('maps common synonyms and sub-categories to natural Vietnamese', () {
      expect(PlaceCategoryHelper.localize('SHOP'), 'Cửa hàng');
      expect(PlaceCategoryHelper.localize('STORE'), 'Cửa hàng');
      expect(PlaceCategoryHelper.localize('LODGING'), 'Khách sạn');
      expect(PlaceCategoryHelper.localize('COFFEE'), 'Quán cà phê');
      expect(PlaceCategoryHelper.localize('BAR'), 'Quán bar / Pub');
      expect(PlaceCategoryHelper.localize('PUB'), 'Quán bar / Pub');
      expect(PlaceCategoryHelper.localize('MUSEUM'), 'Bảo tàng');
      expect(PlaceCategoryHelper.localize('PARK'), 'Công viên');
      expect(PlaceCategoryHelper.localize('BEACH'), 'Bãi biển');
      expect(PlaceCategoryHelper.localize('NATURE'), 'Thiên nhiên');
      expect(PlaceCategoryHelper.localize('TOURIST_ATTRACTION'), 'Điểm tham quan');
      expect(PlaceCategoryHelper.localize('RESORT'), 'Khu nghỉ dưỡng');
      expect(PlaceCategoryHelper.localize('HOMESTAY'), 'Homestay');
      expect(PlaceCategoryHelper.localize('TEMPLE'), 'Chùa / Đền');
    });

    test('handles null, empty and blank values gracefully with fallback', () {
      expect(PlaceCategoryHelper.localize(null), 'Khác');
      expect(PlaceCategoryHelper.localize(''), 'Khác');
      expect(PlaceCategoryHelper.localize('   '), 'Khác');
      expect(PlaceCategoryHelper.localize(null, fallback: 'Chưa xác định'), 'Chưa xác định');
    });

    test('preserves already localized Vietnamese strings', () {
      expect(PlaceCategoryHelper.localize('Điểm tham quan'), 'Điểm tham quan');
      expect(PlaceCategoryHelper.localize('Khách sạn'), 'Khách sạn');
      expect(PlaceCategoryHelper.localize('Quán cà phê ven sông'), 'Quán cà phê ven sông');
    });

    test('formats unknown category keys safely to title case', () {
      expect(PlaceCategoryHelper.localize('HISTORICAL_MONUMENT'), 'Historical Monument');
      expect(PlaceCategoryHelper.localize('scenic-lookout'), 'Scenic Lookout');
    });

    test('model integration provides localizedCategory getter correctly', () {
      const placeSummary = PlaceSummary(
        placeId: 101,
        name: 'Hồ Xuân Hương',
        category: 'ATTRACTION',
        address: 'Đà Lạt',
      );
      expect(placeSummary.localizedCategory, 'Điểm tham quan');

      const destSummary = DestinationSummary(
        destinationId: 202,
        name: 'Khách sạn Colline',
        category: 'HOTEL',
      );
      expect(destSummary.localizedCategory, 'Khách sạn');

      const itineraryPlace = ItineraryPlace(
        id: 303,
        itineraryId: 404,
        place: placeSummary,
      );
      expect(itineraryPlace.localizedCategory, 'Điểm tham quan');
    });
  });
}
