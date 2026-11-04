import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class SocialRepository {
  final ApiClient _apiClient;

  SocialRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> rateItinerary(
    int itineraryId,
    int score, {
    String? token,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.itineraryRatingsEndpoint(itineraryId),
      body: {'score': score},
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }

  Future<void> deleteRating(int itineraryId, {String? token}) async {
    await _apiClient.delete(
      ApiConstants.itineraryRatingsEndpoint(itineraryId),
      token: token,
    );
  }

  Future<Map<String, dynamic>> getRatingSummary(
    int itineraryId, {
    String? token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.itineraryRatingsEndpoint(itineraryId),
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }

  Future<Map<String, dynamic>> getUserRating(
    int itineraryId, {
    String? token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.itineraryUserRatingEndpoint(itineraryId),
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }

  Future<void> addFavorite(int itineraryId, {String? token}) async {
    await _apiClient.post(
      ApiConstants.itineraryFavoritesEndpoint(itineraryId),
      body: {},
      token: token,
    );
  }

  Future<void> removeFavorite(int itineraryId, {String? token}) async {
    await _apiClient.delete(
      ApiConstants.itineraryFavoritesEndpoint(itineraryId),
      token: token,
    );
  }

  Future<void> saveItinerary(int itineraryId, {String? token}) async {
    await _apiClient.post(
      ApiConstants.itinerarySaveEndpoint(itineraryId),
      body: {},
      token: token,
    );
  }

  Future<void> removeSavedItinerary(int itineraryId, {String? token}) async {
    await _apiClient.delete(
      ApiConstants.itinerarySaveEndpoint(itineraryId),
      token: token,
    );
  }
}

