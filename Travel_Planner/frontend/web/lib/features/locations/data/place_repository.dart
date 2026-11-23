import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_storage.dart';
import '../../moderation/data/moderation_repository.dart' show AdminPageResponse;
import 'models/place_model.dart';

export '../../moderation/data/moderation_repository.dart' show AdminPageResponse;

/// Repository for Admin Place CRUD operations on Flutter Web.
class PlaceRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  PlaceRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<String?> _resolveToken(String? token) async {
    return token ?? await _authStorage.getToken();
  }

  /// Retrieves paginated list of places for admin with server-side [totalElements] and [totalPages].
  Future<AdminPageResponse<PlaceModel>> getAdminPlacesPaged({
    String? keyword,
    String? category,
    String? status,
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': sort,
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      queryParams['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty && category != 'ALL') {
      queryParams['category'] = category.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'ALL') {
      queryParams['status'] = status.trim();
    }

    final queryString =
        '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    final response = await _apiClient.get(
      '${ApiConstants.adminPlacesEndpoint}$queryString',
      token: effectiveToken,
    );

    if (response is Map<String, dynamic>) {
      final content = response['content'];
      final List<PlaceModel> list = (content is List)
          ? content
              .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : [];
      final totalElements = response['totalElements'] is num
          ? (response['totalElements'] as num).toInt()
          : list.length;
      final totalPages = response['totalPages'] is num
          ? (response['totalPages'] as num).toInt()
          : (totalElements > 0
              ? (totalElements / size).ceil()
              : (list.isNotEmpty ? 1 : 0));
      final pageNumber = response['pageNumber'] is num
          ? (response['pageNumber'] as num).toInt()
          : (response['number'] is num
              ? (response['number'] as num).toInt()
              : page);

      return AdminPageResponse<PlaceModel>(
        content: list,
        totalElements: totalElements,
        totalPages: totalPages,
        page: pageNumber,
        size: size,
      );
    } else if (response is List) {
      final list = response
          .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return AdminPageResponse<PlaceModel>(
        content: list,
        totalElements: list.length,
        totalPages: list.isNotEmpty ? 1 : 0,
        page: page,
        size: size,
      );
    }

    return AdminPageResponse.empty(page: page, size: size);
  }

  /// Backward-compatible list fetcher.
  Future<List<PlaceModel>> getAdminPlaces({
    String? keyword,
    String? category,
    String? status,
    int page = 0,
    int size = 50,
    String? token,
  }) async {
    final res = await getAdminPlacesPaged(
      keyword: keyword,
      category: category,
      status: status,
      page: page,
      size: size,
      token: token,
    );
    return res.content;
  }

  /// Retrieves single place detail by its ID.
  Future<PlaceModel> getAdminPlaceById(
    int id, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.adminPlaceDetailEndpoint(id),
      token: effectiveToken,
    );
    return PlaceModel.fromJson(response as Map<String, dynamic>);
  }

  /// Creates a new canonical place.
  Future<PlaceModel> createPlace(
    CreatePlaceRequest request, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.post(
      ApiConstants.adminPlacesEndpoint,
      body: request.toJson(),
      token: effectiveToken,
    );
    return PlaceModel.fromJson(response as Map<String, dynamic>);
  }

  /// Updates an existing canonical place.
  Future<PlaceModel> updatePlace(
    int id,
    UpdatePlaceRequest request, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.put(
      ApiConstants.adminPlaceDetailEndpoint(id),
      body: request.toJson(),
      token: effectiveToken,
    );
    return PlaceModel.fromJson(response as Map<String, dynamic>);
  }

  /// Soft-deletes / hides a canonical place.
  Future<void> deletePlace(
    int id, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    await _apiClient.delete(
      ApiConstants.adminPlaceDetailEndpoint(id),
      token: effectiveToken,
    );
  }
}

