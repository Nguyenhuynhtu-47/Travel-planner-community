import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../explore/data/models/itinerary_summary.dart';
import '../../explore/data/models/page_result.dart';
import 'models/activity_detail.dart';
import 'models/create_activity_request.dart';
import 'models/create_day_request.dart';
import 'models/create_itinerary_request.dart';
import 'models/itinerary_day_detail.dart';
import 'models/itinerary_detail.dart';
import 'models/reorder_activity_item.dart';
import 'models/update_activity_request.dart';
import 'models/update_day_request.dart';
import 'models/update_itinerary_request.dart';

class ItineraryCrudRepository {
  final ApiClient _apiClient;

  ApiClient get apiClient => _apiClient;

  ItineraryCrudRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches the authenticated user's itineraries with pagination and optional filters.
  Future<PageResult<ItinerarySummary>> getMyItineraries({
    String? token,
    int page = 0,
    int size = 10,
    String sort = 'createdAt,desc',
    String? status,
    String? visibility,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'size': size,
      'sort': sort,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (visibility != null && visibility.trim().isNotEmpty)
        'visibility': visibility.trim(),
    };

    final response = await _apiClient.get(
      ApiConstants.userItinerariesEndpoint,
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

  /// Creates a new itinerary for the authenticated user.
  Future<ItineraryDetail> createItinerary(
    CreateItineraryRequest request, {
    String? token,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.itinerariesEndpoint,
      body: request.toJson(),
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return ItineraryDetail.fromJson(response);
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  /// Updates an existing itinerary's basic information.
  Future<ItineraryDetail> updateItinerary(
    int itineraryId,
    UpdateItineraryRequest request, {
    String? token,
  }) async {
    final response = await _apiClient.put(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId',
      body: request.toJson(),
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return ItineraryDetail.fromJson(response);
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  /// Soft-deletes an itinerary owned by the authenticated user.
  Future<void> deleteItinerary(int itineraryId, {String? token}) async {
    await _apiClient.delete(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId',
      token: token,
    );
  }

  /// Adds a new day to an itinerary.
  Future<ItineraryDayDetail> addDay(
    int itineraryId,
    CreateDayRequest request, {
    String? token,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days',
      body: request.toJson(),
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return ItineraryDayDetail.fromJson(response);
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  /// Updates an existing day in an itinerary.
  Future<ItineraryDayDetail> updateDay(
    int itineraryId,
    int dayId,
    UpdateDayRequest request, {
    String? token,
  }) async {
    final response = await _apiClient.put(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId',
      body: request.toJson(),
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return ItineraryDayDetail.fromJson(response);
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  /// Deletes a day from an itinerary.
  Future<void> deleteDay(int itineraryId, int dayId, {String? token}) async {
    await _apiClient.delete(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId',
      token: token,
    );
  }

  /// Adds a new activity to an itinerary day.
  Future<ActivityDetail> addActivity(
    int itineraryId,
    int dayId,
    CreateActivityRequest request, {
    String? token,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId/activities',
      body: request.toJson(),
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return ActivityDetail.fromJson(response);
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  /// Updates an activity within an itinerary day.
  Future<ActivityDetail> updateActivity(
    int itineraryId,
    int dayId,
    int activityId,
    UpdateActivityRequest request, {
    String? token,
  }) async {
    final response = await _apiClient.put(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId/activities/$activityId',
      body: request.toJson(),
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return ActivityDetail.fromJson(response);
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }

  /// Deletes an activity from an itinerary day.
  Future<void> deleteActivity(
    int itineraryId,
    int dayId,
    int activityId, {
    String? token,
  }) async {
    await _apiClient.delete(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId/activities/$activityId',
      token: token,
    );
  }

  /// Reorders activities within an itinerary day using a two-pass safe update.
  Future<List<ActivityDetail>> reorderActivities(
    int itineraryId,
    int dayId,
    List<ReorderActivityItem> items, {
    String? token,
  }) async {
    final response = await _apiClient.put(
      '${ApiConstants.itinerariesEndpoint}/$itineraryId/days/$dayId/activities/reorder',
      body: items.map((e) => e.toJson()).toList(),
      token: token,
    );

    if (response is List) {
      return response
          .map((e) => ActivityDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi từ máy chủ không hợp lệ.',
    );
  }
}
