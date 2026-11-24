import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/admin_media_asset_model.dart';
import 'models/admin_post_model.dart';
import 'models/admin_post_report_model.dart';

/// Generic server-side pagination container for Admin data tables.
class AdminPageResponse<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int page;
  final int size;

  const AdminPageResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.page,
    required this.size,
  });

  factory AdminPageResponse.empty({int page = 0, int size = 20}) {
    return AdminPageResponse(
      content: const [],
      totalElements: 0,
      totalPages: 0,
      page: page,
      size: size,
    );
  }
}

class ModerationRepository {
  final ApiClient _apiClient;

  ModerationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches paginated community posts with server-side [totalElements] and [totalPages].
  Future<AdminPageResponse<AdminPostModel>> getPostsPaged({
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
    final path =
        '${ApiConstants.adminCommunityPostsEndpoint}?${queryParams.join('&')}';

    final response = await _apiClient.get(path, token: token);
    if (response is Map<String, dynamic>) {
      final list = (response['content'] is List)
          ? (response['content'] as List)
              .map((item) => AdminPostModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList()
          : <AdminPostModel>[];

      final totalElements = response['totalElements'] is num
          ? (response['totalElements'] as num).toInt()
          : list.length;
      final totalPages = response['totalPages'] is num
          ? (response['totalPages'] as num).toInt()
          : (totalElements > 0 ? (totalElements / size).ceil() : (list.isNotEmpty ? 1 : 0));
      final pageNumber = response['pageNumber'] is num
          ? (response['pageNumber'] as num).toInt()
          : (response['page'] is num ? (response['page'] as num).toInt() : page);

      return AdminPageResponse<AdminPostModel>(
        content: list,
        totalElements: totalElements,
        totalPages: totalPages,
        page: pageNumber,
        size: size,
      );
    }
    return AdminPageResponse.empty(page: page, size: size);
  }

  /// Backward-compatible list fetcher.
  Future<List<AdminPostModel>> getPosts({
    String? status,
    int page = 0,
    int size = 20,
    required String token,
  }) async {
    final res = await getPostsPaged(
      status: status,
      page: page,
      size: size,
      token: token,
    );
    return res.content;
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

  /// Fetches paginated reports with server-side [totalElements] and [totalPages].
  Future<AdminPageResponse<AdminPostReportModel>> getReportsPaged({
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
    final path =
        '${ApiConstants.adminCommunityReportsEndpoint}?${queryParams.join('&')}';

    final response = await _apiClient.get(path, token: token);
    if (response is Map<String, dynamic>) {
      final list = (response['content'] is List)
          ? (response['content'] as List)
              .map((item) => AdminPostReportModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList()
          : <AdminPostReportModel>[];

      final totalElements = response['totalElements'] is num
          ? (response['totalElements'] as num).toInt()
          : list.length;
      final totalPages = response['totalPages'] is num
          ? (response['totalPages'] as num).toInt()
          : (totalElements > 0 ? (totalElements / size).ceil() : (list.isNotEmpty ? 1 : 0));
      final pageNumber = response['pageNumber'] is num
          ? (response['pageNumber'] as num).toInt()
          : (response['page'] is num ? (response['page'] as num).toInt() : page);

      return AdminPageResponse<AdminPostReportModel>(
        content: list,
        totalElements: totalElements,
        totalPages: totalPages,
        page: pageNumber,
        size: size,
      );
    }
    return AdminPageResponse.empty(page: page, size: size);
  }

  /// Backward-compatible list fetcher.
  Future<List<AdminPostReportModel>> getReports({
    String? status,
    int page = 0,
    int size = 20,
    required String token,
  }) async {
    final res = await getReportsPaged(
      status: status,
      page: page,
      size: size,
      token: token,
    );
    return res.content;
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

  /// Fetches paginated media assets with server-side [totalElements] and [totalPages].
  Future<AdminPageResponse<AdminMediaAssetModel>> getMediaAssetsPaged({
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
    final path =
        '${ApiConstants.adminMediaAssetsEndpoint}?${queryParams.join('&')}';

    final response = await _apiClient.get(path, token: token);
    if (response is Map<String, dynamic>) {
      final list = (response['content'] is List)
          ? (response['content'] as List)
              .map((item) => AdminMediaAssetModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList()
          : <AdminMediaAssetModel>[];

      final totalElements = response['totalElements'] is num
          ? (response['totalElements'] as num).toInt()
          : list.length;
      final totalPages = response['totalPages'] is num
          ? (response['totalPages'] as num).toInt()
          : (totalElements > 0 ? (totalElements / size).ceil() : (list.isNotEmpty ? 1 : 0));
      final pageNumber = response['pageNumber'] is num
          ? (response['pageNumber'] as num).toInt()
          : (response['page'] is num ? (response['page'] as num).toInt() : page);

      return AdminPageResponse<AdminMediaAssetModel>(
        content: list,
        totalElements: totalElements,
        totalPages: totalPages,
        page: pageNumber,
        size: size,
      );
    }
    return AdminPageResponse.empty(page: page, size: size);
  }

  /// Backward-compatible list fetcher.
  Future<List<AdminMediaAssetModel>> getMediaAssets({
    String? status,
    bool deadLetterOnly = false,
    int page = 0,
    int size = 20,
    required String token,
  }) async {
    final res = await getMediaAssetsPaged(
      status: status,
      deadLetterOnly: deadLetterOnly,
      page: page,
      size: size,
      token: token,
    );
    return res.content;
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

