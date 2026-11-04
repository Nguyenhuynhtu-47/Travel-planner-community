import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../explore/data/models/itinerary_summary.dart';
import '../../explore/data/models/page_result.dart';

class CollectionRepository {
  final ApiClient _apiClient;

  CollectionRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<PageResult<ItinerarySummary>> getSavedItineraries({
    int page = 0,
    int size = 10,
    String? token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.savedItinerariesEndpoint,
      queryParameters: {'page': page, 'size': size},
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return PageResult.fromJson(
        response,
        (item) => ItinerarySummary.fromJson(item as Map<String, dynamic>),
      );
    }

    return const PageResult(
      content: [],
      pageNumber: 0,
      pageSize: 10,
      totalElements: 0,
      totalPages: 0,
      isLast: true,
    );
  }

  Future<PageResult<ItinerarySummary>> getFavoriteItineraries({
    int page = 0,
    int size = 10,
    String? token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.userFavoritesEndpoint,
      queryParameters: {'page': page, 'size': size},
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return PageResult.fromJson(
        response,
        (item) => ItinerarySummary.fromJson(item as Map<String, dynamic>),
      );
    }

    return const PageResult(
      content: [],
      pageNumber: 0,
      pageSize: 10,
      totalElements: 0,
      totalPages: 0,
      isLast: true,
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
}

