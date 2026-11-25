import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_storage.dart';
import '../../locations/data/models/place_model.dart';
import 'models/administrative_area_model.dart';

/// Repository for Administrative Areas hierarchy, coverage stats,
/// sequential batch resolution (chunk 50), and place linking (IDs 5.6-5.9).
class AdministrativeAreaRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  AdministrativeAreaRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<String?> _resolveToken(String? token) async {
    return token ?? await _authStorage.getToken();
  }

  /// ID 5.6: Load dynamic province-level administrative units.
  Future<List<AdministrativeAreaNodeModel>> getProvinces({String? token}) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.administrativeAreasProvincesEndpoint,
      token: effectiveToken,
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(AdministrativeAreaNodeModel.fromJson)
          .toList();
    }
    return [];
  }

  /// ID 5.6: Load child communes/wards/special zones for a parent province code.
  Future<List<AdministrativeAreaNodeModel>> getChildren(
    String parentCode, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.administrativeAreaChildrenEndpoint(
          Uri.encodeComponent(parentCode)),
      token: effectiveToken,
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(AdministrativeAreaNodeModel.fromJson)
          .toList();
    }
    return [];
  }

  /// Search administrative areas by name/code (with parent context).
  Future<List<AdministrativeAreaSummaryModel>> searchAreas(
    String query, {
    int limit = 15,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final encodedQ = Uri.encodeComponent(query.trim());
    final response = await _apiClient.get(
      '${ApiConstants.administrativeAreasSearchEndpoint}?q=$encodedQ&limit=$limit',
      token: effectiveToken,
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(AdministrativeAreaSummaryModel.fromJson)
          .toList();
    }
    return [];
  }

  /// ID 5.7: Retrieve real-time administrative area coverage statistics.
  Future<AdministrativeAreaStatsModel> getCoverageStats({String? token}) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.adminPlaceAdminAreaStatsEndpoint,
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return AdministrativeAreaStatsModel.fromJson(response);
    }
    throw Exception('Phản hồi thống kê khu vực hành chính không hợp lệ.');
  }

  /// ID 5.8: Run a single synchronous batch (max 50 placeIds).
  Future<BatchLinkingReportModel> batchResolve({
    required List<int> placeIds,
    bool dryRun = true,
    bool overwriteExisting = false,
    String? token,
  }) async {
    assert(placeIds.length <= 50, 'Mỗi batch tối đa 50 địa điểm.');
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.post(
      ApiConstants.adminPlaceAdminAreaBatchResolveEndpoint,
      body: {
        'dryRun': dryRun,
        'overwriteExisting': overwriteExisting,
        'placeIds': placeIds,
      },
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return BatchLinkingReportModel.fromJson(response);
    }
    throw Exception('Phản hồi Batch Resolve không hợp lệ.');
  }

  /// ID 5.9: Preview automatic administrative area resolution for a place.
  Future<PlaceResolutionResultModel> previewPlaceResolution(
    int placeId, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.post(
      ApiConstants.adminPlaceAdminAreaPreviewEndpoint(placeId),
      body: const {},
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return PlaceResolutionResultModel.fromJson(response);
    }
    throw Exception('Phản hồi xem trước khu vực hành chính không hợp lệ.');
  }

  /// ID 5.9: Auto-resolve and link a single place if eligible.
  Future<PlaceResolutionResultModel> resolveAndLinkPlace(
    int placeId, {
    bool overwriteExisting = true,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.post(
      '${ApiConstants.adminPlaceAdminAreaResolveEndpoint(placeId)}?overwriteExisting=$overwriteExisting',
      body: const {},
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return PlaceResolutionResultModel.fromJson(response);
    }
    throw Exception('Phản hồi tự động gán khu vực hành chính không hợp lệ.');
  }

  /// ID 5.9: Manually link a place to an administrative area code.
  Future<PlaceModel> linkPlaceManually({
    required int placeId,
    required String administrativeAreaCode,
    required String reason,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.post(
      ApiConstants.adminPlaceAdminAreaLinkEndpoint(placeId),
      body: {
        'administrativeAreaCode': administrativeAreaCode.trim(),
        'reason': reason.trim(),
      },
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return PlaceModel.fromJson(response);
    }
    throw Exception('Phản hồi gán mã khu vực hành chính không hợp lệ.');
  }

  /// ID 5.9: Unlink administrative area from a place.
  Future<PlaceModel> unlinkPlace(
    int placeId, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.delete(
      ApiConstants.adminPlaceAdminAreaUnlinkEndpoint(placeId),
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return PlaceModel.fromJson(response);
    }
    throw Exception('Phản hồi gỡ mã khu vực hành chính không hợp lệ.');
  }
}
