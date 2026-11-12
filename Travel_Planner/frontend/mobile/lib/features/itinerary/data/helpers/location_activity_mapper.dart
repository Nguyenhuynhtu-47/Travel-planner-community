import '../models/create_activity_request.dart';
import '../../../location/data/models/location_search_result.dart';

/// Helper responsible for mapping various [LocationSearchResult] types
/// into a [CreateActivityRequest] payload for Phase 6A.2.
///
/// Strictly enforces backend invariants:
/// 1. Internal Place (places catalog): Sets [canonicalPlaceId], sets [latitude] and [longitude] to null.
///    Backend rule: "Không thể đồng thời chỉ định địa điểm từ danh mục và tọa độ tùy chỉnh".
/// 2. External POI (TomTom, LocationIQ, HERE): [canonicalPlaceId] is null, preserves coordinates,
///    provider, and provider placeId. Prohibited from inserting into MySQL places catalog.
/// 3. Manual Pin: [canonicalPlaceId] is null, preserves coordinates, provider = 'MANUAL_PIN'.
/// 4. Administrative Area: Boundary entity; disallows scheduling activity, throws [ArgumentError].
class LocationActivityMapper {
  /// Converts a [LocationSearchResult] to a [CreateActivityRequest].
  static CreateActivityRequest toCreateRequest({
    required LocationSearchResult location,
    required String name,
    String? description,
    String? startTime,
    String? endTime,
    double? cost,
    String? imageUrl,
  }) {
    if (location.isAdministrativeArea) {
      throw ArgumentError(
        'Ranh giới khu vực hành chính không thể lên lịch thành hoạt động.',
      );
    }

    final trimmedName = name.trim();
    final effectiveName = trimmedName.isNotEmpty
        ? trimmedName
        : (location.name.isNotEmpty ? location.name : 'Hoạt động mới');

    final address = location.formattedAddress.isNotEmpty
        ? location.formattedAddress
        : null;

    if (location.isInternalPlace) {
      return CreateActivityRequest(
        name: effectiveName,
        description: description,
        canonicalPlaceId: location.internalPlaceId,
        destinationId: null,
        latitude: null, // Strictly null to respect backend invariant
        longitude: null, // Strictly null to respect backend invariant
        locationName: location.name,
        locationAddress: address,
        customLocationName: location.name,
        customAddress: address,
        placeId: location.placeId,
        locationProvider: 'PLACE_CATALOG',
        startTime: startTime,
        endTime: endTime,
        cost: cost,
        imageUrl: imageUrl,
      );
    }

    // External POI or Manual Pin
    final isManualPin = location.provider == 'MANUAL_PIN' ||
        location.placeId.isEmpty;
    final locName = location.name.isNotEmpty
        ? location.name
        : (isManualPin ? 'Vị trí đã ghim' : 'Địa điểm đã chọn');
    final provider = isManualPin
        ? 'MANUAL_PIN'
        : (location.provider ?? 'LOCATION_IQ');
    final pid = isManualPin
        ? null
        : (location.placeId.isNotEmpty ? location.placeId : null);

    return CreateActivityRequest(
      name: effectiveName,
      description: description,
      canonicalPlaceId: null,
      destinationId: null,
      latitude: location.latitude,
      longitude: location.longitude,
      locationName: locName,
      locationAddress: address,
      customLocationName: locName,
      customAddress: address,
      placeId: pid,
      locationProvider: provider,
      startTime: startTime,
      endTime: endTime,
      cost: cost,
      imageUrl: imageUrl,
    );
  }
}

