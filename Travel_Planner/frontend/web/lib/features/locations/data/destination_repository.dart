import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_storage.dart';
import 'models/destination_model.dart';

/// Repository for Admin Destination CRUD operations on Flutter Web.
class DestinationRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  DestinationRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<String?> _resolveToken(String? token) async {
    return token ?? await _authStorage.getToken();
  }

  /// Retrieves list of destinations for admin, optionally filtered by keyword and status.
  Future<List<Destination>> getAdminDestinations({
    String? keyword,
    String? status,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final queryParams = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      queryParams['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'ALL') {
      queryParams['status'] = status.trim();
    }

    String queryString = '';
    if (queryParams.isNotEmpty) {
      queryString =
          '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
    }

    final response = await _apiClient.get(
      '${ApiConstants.adminDestinationsEndpoint}$queryString',
      token: effectiveToken,
    );

    if (response is List) {
      return response
          .map((item) => Destination.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Retrieves single destination detail by its primary key ID.
  Future<Destination> getAdminDestinationById(
    int id, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.adminDestinationDetailEndpoint(id),
      token: effectiveToken,
    );

    return Destination.fromJson(response as Map<String, dynamic>);
  }

  /// Creates a new destination in the catalog.
  Future<Destination> createDestination(
    CreateDestinationRequest request, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.post(
      ApiConstants.adminDestinationsEndpoint,
      body: request.toJson(),
      token: effectiveToken,
    );

    return Destination.fromJson(response as Map<String, dynamic>);
  }

  /// Updates an existing destination in the catalog.
  Future<Destination> updateDestination(
    int id,
    UpdateDestinationRequest request, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.put(
      ApiConstants.adminDestinationDetailEndpoint(id),
      body: request.toJson(),
      token: effectiveToken,
    );

    return Destination.fromJson(response as Map<String, dynamic>);
  }

  /// Soft-deletes (hides) a destination by ID.
  Future<void> deleteDestination(
    int id, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    await _apiClient.delete(
      ApiConstants.adminDestinationDetailEndpoint(id),
      token: effectiveToken,
    );
  }
}
