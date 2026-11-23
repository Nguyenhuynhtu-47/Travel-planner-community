import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/admin_media_asset_model.dart';
import 'models/admin_post_model.dart';
import 'models/admin_post_report_model.dart';

class ModerationRepository {
  final ApiClient _apiClient;

  ModerationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<AdminPostModel>> getPosts({
    String? status,
    int page = 0,
    int size = 20,
    required String token,
  }) async {
    final queryParams = <String>[
      'page=$page',
      'size=$size',
      if (status != null && status.isNotEmpty) 'status=$status',
    ];
    final path = '${ApiConstants.adminCommunityPostsEndpoint}?${queryParams.join('&')}';

    final response = await _apiClient.get(path, token: token);
    if (response is Map<String, dynamic> && response['content'] is List) {
      final list = response['content'] as List;
      return list
          .map((item) =>
              AdminPostModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<AdminPostModel> getPostById(
    int postId, {
    required String token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.adminCommunityPostDetailEndpoint(postId),
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminPostModel.fromJson(response);
    }
    throw Exception('Không thể tải chi tiết bài viết');
  }

  Future<AdminPostModel> moderatePost(
    int postId, {
    required String status,
    String? reason,
    required String token,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (reason != null && reason.trim().isNotEmpty)
        'moderationReason': reason.trim(),
    };
    final response = await _apiClient.patch(
      ApiConstants.adminCommunityPostModerateEndpoint(postId),
      body: body,
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminPostModel.fromJson(response);
    }
    throw Exception('Không thể cập nhật trạng thái bài viết');
  }

  Future<void> purgePost(
    int postId, {
    required String token,
  }) async {
    await _apiClient.delete(
      ApiConstants.adminCommunityPostPurgeEndpoint(postId),
      token: token,
    );
  }

  Future<List<AdminPostReportModel>> getReports({
    String? status,
    int page = 0,
    int size = 20,
    required String token,
  }) async {
    final queryParams = <String>[
      'page=$page',
      'size=$size',
      if (status != null && status.isNotEmpty) 'status=$status',
    ];
    final path = '${ApiConstants.adminCommunityReportsEndpoint}?${queryParams.join('&')}';

    final response = await _apiClient.get(path, token: token);
    if (response is Map<String, dynamic> && response['content'] is List) {
      final list = response['content'] as List;
      return list
          .map((item) => AdminPostReportModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<AdminPostReportModel> getReportById(
    int reportId, {
    required String token,
  }) async {
    final response = await _apiClient.get(
      ApiConstants.adminCommunityReportDetailEndpoint(reportId),
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminPostReportModel.fromJson(response);
    }
    throw Exception('Không thể tải chi tiết báo cáo');
  }

  Future<AdminPostReportModel> resolveReport(
    int reportId, {
    required String status,
    required String token,
  }) async {
    final body = {
      'status': status,
      'resolution': status,
    };
    final path =
        '${ApiConstants.adminCommunityReportResolveEndpoint(reportId)}?resolution=$status';
    final response = await _apiClient.patch(
      path,
      body: body,
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return AdminPostReportModel.fromJson(response);
    }
    throw Exception('Không thể cập nhật trạng thái báo cáo');
  }

  Future<List<AdminMediaAssetModel>> getMediaAssets({
    String? status,
    bool deadLetterOnly = false,
    int page = 0,
    int size = 20,
    required String token,
  }) async {
    final queryParams = <String>[
      'page=$page',
      'size=$size',
      if (status != null && status.isNotEmpty) 'status=$status',
      if (deadLetterOnly) 'deadLetterOnly=true',
    ];
    final path = '${ApiConstants.adminMediaAssetsEndpoint}?${queryParams.join('&')}';

    final response = await _apiClient.get(path, token: token);
    if (response is Map<String, dynamic> && response['content'] is List) {
      final list = response['content'] as List;
      return list
          .map((item) => AdminMediaAssetModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<void> retryMediaAsset(
    int mediaAssetId, {
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.adminMediaAssetRetryEndpoint(mediaAssetId),
      body: {},
      token: token,
    );
    if (response is Map<String, dynamic>) {
      // Backend returned updated asset representation
      return;
    }
    // If response is null / empty 200 OK, success
  }
}

