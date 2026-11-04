import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/itinerary/data/models/activity_detail.dart';
import 'package:mobile/features/itinerary/data/models/create_activity_request.dart';
import 'package:mobile/features/itinerary/data/models/destination_summary.dart';
import 'package:mobile/features/itinerary/data/models/update_activity_request.dart';

void main() {
  group('Phase 1 - Activity Location Data Models', () {
    test('State 1: Catalog Destination model and effective getters', () {
      final activity = ActivityDetail(
        activityId: 1,
        name: 'Thăm Chùa Cầu',
        displayOrder: 1,
        destination: const DestinationSummary(
          destinationId: 101,
          name: 'Chùa Cầu Hội An',
          address: 'Nguyễn Thị Minh Khai, Hội An',
          latitude: 15.877112,
          longitude: 108.325983,
        ),
      );

      expect(activity.hasCoordinates, isTrue);
      expect(activity.effectiveLatitude, 15.877112);
      expect(activity.effectiveLongitude, 108.325983);
      expect(activity.effectiveLocationName, 'Chùa Cầu Hội An');
      expect(activity.effectiveAddress, 'Nguyễn Thị Minh Khai, Hội An');
      expect(activity.customLocationName, isNull);
    });

    test('State 2: Custom Location model and effective getters', () {
      final activity = ActivityDetail(
        activityId: 2,
        name: 'Ăn tối quán ven sông',
        displayOrder: 2,
        customLocationName: 'Quán Cá Nướng Bờ Sông',
        customAddress: 'Bờ Kè Sông Hàn, Đà Nẵng',
        latitude: 16.061234,
        longitude: 108.223456,
        placeId: 'custom-osm-12345',
        locationProvider: 'nominatim',
      );

      expect(activity.hasCoordinates, isTrue);
      expect(activity.effectiveLatitude, 16.061234);
      expect(activity.effectiveLongitude, 108.223456);
      expect(activity.effectiveLocationName, 'Quán Cá Nướng Bờ Sông');
      expect(activity.effectiveAddress, 'Bờ Kè Sông Hàn, Đà Nẵng');
      expect(activity.destination, isNull);
    });

    test('State 3: No Location model hasCoordinates is false', () {
      final activity = const ActivityDetail(
        activityId: 3,
        name: 'Nghỉ ngơi tự do',
        displayOrder: 3,
      );

      expect(activity.hasCoordinates, isFalse);
      expect(activity.effectiveLatitude, isNull);
      expect(activity.effectiveLongitude, isNull);
      expect(activity.effectiveLocationName, isNull);
      expect(activity.effectiveAddress, isNull);
    });

    test('Backward Compatibility: JSON without custom location fields deserializes cleanly', () {
      final legacyJson = {
        'activityId': 42,
        'name': 'Hoạt động cũ',
        'description': 'Mô tả từ bản dựng trước',
        'cost': 150000.0,
        'displayOrder': 1,
        'destination': {
          'destinationId': 55,
          'name': 'Hồ Gươm',
          'address': 'Hoàn Kiếm, Hà Nội',
          'latitude': 21.028511,
          'longitude': 105.854444,
        },
      };

      final activity = ActivityDetail.fromJson(legacyJson);
      expect(activity.activityId, 42);
      expect(activity.name, 'Hoạt động cũ');
      expect(activity.customLocationName, isNull);
      expect(activity.customAddress, isNull);
      expect(activity.latitude, isNull);
      expect(activity.longitude, isNull);
      expect(activity.hasCoordinates, isTrue);
      expect(activity.effectiveLatitude, 21.028511);
      expect(activity.effectiveLongitude, 105.854444);
    });

    test('ActivityDetail.fromJson parses custom location fields correctly', () {
      final json = {
        'activityId': 88,
        'name': 'Cà phê sách',
        'displayOrder': 1,
        'customLocationName': 'Nhà Sách Cá Chép',
        'customAddress': '211 Võ Văn Tần, Q.3, TP.HCM',
        'latitude': 10.774512,
        'longitude': 106.689234,
        'placeId': 'custom-place-888',
        'locationProvider': 'nominatim',
      };

      final activity = ActivityDetail.fromJson(json);
      expect(activity.customLocationName, 'Nhà Sách Cá Chép');
      expect(activity.customAddress, '211 Võ Văn Tần, Q.3, TP.HCM');
      expect(activity.latitude, 10.774512);
      expect(activity.longitude, 106.689234);
      expect(activity.placeId, 'custom-place-888');
      expect(activity.locationProvider, 'nominatim');
      expect(activity.hasCoordinates, isTrue);
      expect(activity.effectiveLocationName, 'Nhà Sách Cá Chép');
    });

    test('CreateActivityRequest.toJson serializes custom location fields', () {
      const req = CreateActivityRequest(
        name: 'Ăn trưa',
        customLocationName: 'Bún Chả Hương Liên',
        customAddress: '24 Lê Văn Hưu, Hà Nội',
        latitude: 21.0187,
        longitude: 105.8524,
        placeId: 'node-999',
        locationProvider: 'nominatim',
      );

      final json = req.toJson();
      expect(json['name'], 'Ăn trưa');
      expect(json['customLocationName'], 'Bún Chả Hương Liên');
      expect(json['customAddress'], '24 Lê Văn Hưu, Hà Nội');
      expect(json['latitude'], 21.0187);
      expect(json['longitude'], 105.8524);
      expect(json['placeId'], 'node-999');
      expect(json['locationProvider'], 'nominatim');
      expect(json.containsKey('destinationId'), isFalse);
    });

    test('UpdateActivityRequest.toJson serializes null custom fields for state transitions', () {
      const req = UpdateActivityRequest(
        name: 'Chuyển sang Catalog Destination',
        destinationId: 99,
        customLocationName: null,
        customAddress: null,
        latitude: null,
        longitude: null,
      );

      final json = req.toJson();
      expect(json['destinationId'], 99);
      expect(json['customLocationName'], isNull);
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
    });

    UpdateActivityRequest buildSimulatedFormUpdateRequest({
      required ActivityDetail initial,
      required String name,
      int? selectedDestId,
    }) {
      return UpdateActivityRequest(
        name: name,
        destinationId: selectedDestId,
        customLocationName:
            selectedDestId == null ? initial.customLocationName : null,
        customAddress: selectedDestId == null ? initial.customAddress : null,
        latitude: selectedDestId == null ? initial.latitude : null,
        longitude: selectedDestId == null ? initial.longitude : null,
        placeId: selectedDestId == null ? initial.placeId : null,
        locationProvider:
            selectedDestId == null ? initial.locationProvider : null,
      );
    }

    test('Normal edit of custom location activity preserves coordinates in UpdateActivityRequest', () {
      final initialActivity = const ActivityDetail(
        activityId: 10,
        name: 'Quán Ven Sông Cũ',
        displayOrder: 1,
        customLocationName: 'Quán Cá Nướng',
        customAddress: 'Bờ Kè Sông Hàn',
        latitude: 16.0612,
        longitude: 108.2234,
        placeId: 'custom-place-10',
        locationProvider: 'nominatim',
      );

      // Normal edit without picking a catalog destination preserves existing custom location
      final updateReq = buildSimulatedFormUpdateRequest(
        initial: initialActivity,
        name: 'Quán Ven Sông Mới Đổi Tên',
        selectedDestId: null,
      );

      final json = updateReq.toJson();
      expect(json['name'], 'Quán Ven Sông Mới Đổi Tên');
      expect(json['destinationId'], isNull);
      expect(json['customLocationName'], 'Quán Cá Nướng');
      expect(json['customAddress'], 'Bờ Kè Sông Hàn');
      expect(json['latitude'], 16.0612);
      expect(json['longitude'], 108.2234);
      expect(json['placeId'], 'custom-place-10');
      expect(json['locationProvider'], 'nominatim');
    });

    test('Switching from Custom Location to Catalog Destination zeroes custom fields', () {
      final initialActivity = const ActivityDetail(
        activityId: 10,
        name: 'Quán Ven Sông',
        displayOrder: 1,
        customLocationName: 'Quán Cá Nướng',
        latitude: 16.0612,
        longitude: 108.2234,
      );

      // User selects a catalog destination (id = 45)
      final updateReq = buildSimulatedFormUpdateRequest(
        initial: initialActivity,
        name: 'Chuyển sang Chùa Cầu',
        selectedDestId: 45,
      );

      final json = updateReq.toJson();
      expect(json['destinationId'], 45);
      expect(json['customLocationName'], isNull);
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
    });
  });
}
