import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_storage.dart';
import 'models/place_model.dart';

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

  /// Retrieves list of places for admin, optionally filtered by keyword, category, and status.
  Future<List<PlaceModel>> getAdminPlaces({
    String? keyword,
    String? category,
    String? status,
    int page = 0,
    int size = 50,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
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
      if (content is List) {
        return content
            .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } else if (response is List) {
      return response
          .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
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

