import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../moderation/data/moderation_repository.dart';
import 'models/admin_user_model.dart';

class AdminUserRepository {
  final ApiClient _apiClient;

  AdminUserRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<AdminPageResponse<AdminUserModel>> getUsersPaged({
    String? keyword,
    String? role,
    String? status,
    int page = 0,
    int size = 20,
    String? sort,
    required String token,
  }) async {
    final queryParams = <String>[
      'page=$page',
      'size=$size',
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword=${Uri.encodeQueryComponent(keyword.trim())}',
      if (role != null && role.isNotEmpty) 'role=${Uri.encodeQueryComponent(role)}',
      if (status != null && status.isNotEmpty) 'status=${Uri.encodeQueryComponent(status)}',
      if (sort != null && sort.isNotEmpty) 'sort=${Uri.encodeQueryComponent(sort)}',
    ];

    final path = '${ApiConstants.adminUsersEndpoint}?${queryParams.join('&')}';
    final response = await _apiClient.get(path, token: token);

    if (response is Map<String, dynamic>) {
      final list = (response['content'] is List)
          ? (response['content'] as List)
              .map((item) => AdminUserModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList()
          : <AdminUserModel>[];

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
          : (response['page'] is num ? (response['page'] as num).toInt() : page);

      return AdminPageResponse<AdminUserModel>(
        content: list,
        totalElements: totalElements,
        totalPages: totalPages,
        page: pageNumber,
        size: size,
      );
    }

    return AdminPageResponse.empty(page: page, size: size);
  }

  Future<AdminUserDetailModel> getUserDetail(
    int userId, {
    required String token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.adminUserDetailEndpoint(userId),
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminUserDetailModel.fromJson(response);
    }
    throw Exception('Không thể tải chi tiết người dùng');
  }

  Future<AdminUserModel> updateUserStatus(
    int userId, {
    required String status,
    required String reason,
    required String token,
  }) async {
    final response = await _apiClient.patch(
      ApiConstants.adminUserStatusEndpoint(userId),
      body: {
        'status': status,
        'reason': reason.trim(),
      },
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminUserModel.fromJson(response);
    }
    throw Exception('Không thể cập nhật trạng thái tài khoản');
  }

  Future<AdminUserModel> updateUserRole(
    int userId, {
    required String role,
    required String reason,
    required String token,
  }) async {
    final response = await _apiClient.patch(
      ApiConstants.adminUserRoleEndpoint(userId),
      body: {
        'role': role,
        'reason': reason.trim(),
      },
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminUserModel.fromJson(response);
    }
    throw Exception('Không thể cập nhật vai trò tài khoản');
  }

  Future<int> revokeAllSessions(
    int userId, {
    String? reason,
    required String token,
  }) async {
    final query = (reason != null && reason.trim().isNotEmpty)
        ? '?reason=${Uri.encodeQueryComponent(reason.trim())}'
        : '';
    final response = await _apiClient.post(
      '${ApiConstants.adminUserRevokeSessionsEndpoint(userId)}$query',
      body: const {},
      token: token,
    );
    if (response is Map<String, dynamic> && response['revokedCount'] is num) {
      return (response['revokedCount'] as num).toInt();
    }
    return 0;
  }
}
