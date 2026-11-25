import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_storage.dart';
import '../../moderation/data/moderation_repository.dart' show AdminPageResponse;
import 'models/audit_log_model.dart';

/// Read-only repository for querying immutable administrative audit logs.
class AuditLogRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  AuditLogRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<String?> _resolveToken(String? token) async {
    return token ?? await _authStorage.getToken();
  }

  Future<AdminPageResponse<AuditLogModel>> getAuditLogsPaged({
    String? keyword,
    String? actorUsername,
    String? actionType,
    String? targetType,
    String? targetId,
    String? resultStatus,
    String? fromDate,
    String? toDate,
    int page = 0,
    int size = 20,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };

    void addIfSet(String key, String? value) {
      if (value != null && value.trim().isNotEmpty && value != 'ALL') {
        queryParams[key] = value.trim();
      }
    }

    addIfSet('keyword', keyword);
    addIfSet('actorUsername', actorUsername);
    addIfSet('actionType', actionType);
    addIfSet('targetType', targetType);
    addIfSet('targetId', targetId);
    addIfSet('resultStatus', resultStatus);
    addIfSet('fromDate', fromDate);
    addIfSet('toDate', toDate);

    final queryString =
        '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    final response = await _apiClient.get(
      '${ApiConstants.adminAuditLogsEndpoint}$queryString',
      token: effectiveToken,
    );

    if (response is Map<String, dynamic>) {
      final content = response['content'];
      final list = (content is List)
          ? content
              .whereType<Map<String, dynamic>>()
              .map(AuditLogModel.fromJson)
              .toList()
          : <AuditLogModel>[];

      final totalElements = response['totalElements'] is num
          ? (response['totalElements'] as num).toInt()
          : list.length;
      final totalPages = response['totalPages'] is num
          ? (response['totalPages'] as num).toInt()
          : (totalElements > 0 ? (totalElements / size).ceil() : 0);
      final pageNumber = response['pageNumber'] is num
          ? (response['pageNumber'] as num).toInt()
          : page;

      return AdminPageResponse<AuditLogModel>(
        content: list,
        totalElements: totalElements,
        totalPages: totalPages,
        page: pageNumber,
        size: size,
      );
    }

    return AdminPageResponse.empty(page: page, size: size);
  }

  Future<AuditLogDetailModel> getAuditLogById(
    int logId, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.adminAuditLogDetailEndpoint(logId),
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return AuditLogDetailModel.fromJson(response);
    }
    throw Exception('Phản hồi chi tiết nhật ký kiểm toán không hợp lệ.');
  }
}
