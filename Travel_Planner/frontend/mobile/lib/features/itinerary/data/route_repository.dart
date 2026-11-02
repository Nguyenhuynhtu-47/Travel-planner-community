import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/route_models.dart';

/// Repository for retrieving per-day calculated road routes from the backend API.
class RouteRepository {
  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  RouteRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Retrieves the calculated road route (or straight-line fallback) for a specific day in an itinerary.
  Future<RouteResponse> getDayRoute({
    required int itineraryId,
    required int dayId,
    String mode = 'driving',
    String? token,
  }) async {
    final endpoint =
        '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId/route';
    final queryParams = {'mode': mode};

    final response = await _apiClient.get(
      endpoint,
      queryParameters: queryParams,
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return RouteResponse.fromJson(response);
    } else if (response is Map) {
      return RouteResponse.fromJson(Map<String, dynamic>.from(response));
    }

    throw Exception('Phản hồi không hợp lệ từ máy chủ lộ trình');
  }
}

