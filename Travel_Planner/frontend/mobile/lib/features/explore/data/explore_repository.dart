import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/itinerary_summary.dart';
import 'models/page_result.dart';

class ExploreRepository {
  final ApiClient _apiClient;

  ExploreRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<PageResult<ItinerarySummary>> getPublicItineraries({
    String? keyword,
    String? location,
    String? theme,
    double? minBudget,
    double? maxBudget,
    int? minDays,
    int? maxDays,
    double? minRating,
    int page = 0,
    int size = 10,
    String sort = 'createdAt,desc',
    String? token,
  }) async {
    final queryParameters = <String, dynamic>{
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (theme != null && theme.trim().isNotEmpty) 'theme': theme.trim(),
      if (minBudget != null && minBudget >= 0) 'minBudget': minBudget,
      if (maxBudget != null && maxBudget >= 0) 'maxBudget': maxBudget,
      if (minDays != null && minDays >= 1) 'minDays': minDays,
      if (maxDays != null && maxDays >= 1) 'maxDays': maxDays,
      if (minRating != null && minRating >= 1.0) 'minRating': minRating,
      'page': page,
      'size': size,
      'sort': sort,
    };

    final response = await _apiClient.get(
      ApiConstants.itinerariesEndpoint,
      queryParameters: queryParameters,
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
}
