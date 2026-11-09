import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'models/location_search_result.dart';

class LocationRepository {
  final ApiClient _apiClient;

  LocationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Search places and autocomplete locations by query.
  ///
  /// If [query] after trimming is shorter than 2 characters, returns an empty list
  /// without calling the backend.
  Future<List<LocationSearchResult>> searchLocations(
    String query, {
    int? limit,
    String? token,
    String mode = 'SUGGEST',
    String? sessionId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const [];
    }

    final queryParameters = <String, dynamic>{
      'query': trimmed,
      'mode': mode,
      'sessionId': ?sessionId,
      if (limit != null && limit >= 1 && limit <= 20) 'limit': limit,
    };

    final response = await _apiClient.get(
      ApiConstants.locationSearchEndpoint,
      queryParameters: queryParameters,
      token: token,
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(LocationSearchResult.fromJson)
          .toList();
    }

    return const [];
  }

  Future<LocationSearchResult?> resolveTomTomPlace({
    required String type,
    required String id,
    String? sessionId,
    String? token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.locationTomTomDetailsEndpoint,
      queryParameters: {'type': type, 'id': id, 'sessionId': ?sessionId},
      token: token,
    );
    return response is Map<String, dynamic>
        ? LocationSearchResult.fromJson(response)
        : null;
  }

  /// Reverse geocodes coordinates (latitude, longitude) to place information.
  ///
  /// Returns `null` if the coordinate does not resolve to an address (HTTP 404).
  /// Rethrows other [ApiException] instances (e.g. rate limit HTTP 429).
  Future<LocationSearchResult?> reverseGeocode(
    double latitude,
    double longitude, {
    String? token,
  }) async {
    final queryParameters = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };

    try {
      final response = await _apiClient.get(
        ApiConstants.locationReverseGeocodeEndpoint,
        queryParameters: queryParameters,
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return LocationSearchResult.fromJson(response);
      }

      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
