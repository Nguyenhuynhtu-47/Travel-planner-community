import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/itinerary_detail.dart';

class ItineraryRepository {
  final ApiClient _apiClient;

  ItineraryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ItineraryDetail> getItineraryDetail(
    int itineraryId, {
    String? token,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId',
      token: token,
    );

    if (response is Map) {
      return ItineraryDetail.fromJson(Map<String, dynamic>.from(response));
    }

    throw Exception('Phản hồi từ máy chủ không hợp lệ.');
  }
}
