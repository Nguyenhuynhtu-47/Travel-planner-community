import 'package:travel_planner_web/core/constants/api_constants.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_report_model.dart';

class AdminDashboardData {
  final int placesCount;
  final int postsCount;
  final int pendingReportsCount;
  final int mediaAssetsCount;
  final String healthStatus;
  final String? serviceName;
  final String? serverTimestamp;
  final List<AdminPostReportModel> recentPendingReports;
  final List<AdminPostModel> recentPosts;
  final String? errorMessage;

  const AdminDashboardData({
    required this.placesCount,
    required this.postsCount,
    required this.pendingReportsCount,
    required this.mediaAssetsCount,
    required this.healthStatus,
    this.serviceName,
    this.serverTimestamp,
    this.recentPendingReports = const [],
    this.recentPosts = const [],
    this.errorMessage,
  });

  factory AdminDashboardData.empty() {
    return const AdminDashboardData(
      placesCount: 0,
      postsCount: 0,
      pendingReportsCount: 0,
      mediaAssetsCount: 0,
      healthStatus: 'UNKNOWN',
    );
  }
}

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<AdminDashboardData> fetchDashboardData(String? token) async {
    int placesCount = 0;
    int postsCount = 0;
    int pendingReportsCount = 0;
    int mediaAssetsCount = 0;
    String healthStatus = 'UNKNOWN';
    String? serviceName;
    String? serverTimestamp;
    List<AdminPostReportModel> recentReports = [];
    List<AdminPostModel> recentPosts = [];

    // 1. Health check
    try {
      final res = await _apiClient.get(ApiConstants.healthEndpoint);
      if (res is Map<String, dynamic>) {
        healthStatus = res['status']?.toString() ?? 'UP';
        serviceName = res['service']?.toString();
        serverTimestamp = res['timestamp']?.toString();
      }
    } catch (_) {
      healthStatus = 'UNAVAILABLE';
    }

    if (token == null || token.isEmpty) {
      return AdminDashboardData(
        placesCount: placesCount,
        postsCount: postsCount,
        pendingReportsCount: pendingReportsCount,
        mediaAssetsCount: mediaAssetsCount,
        healthStatus: healthStatus,
        serviceName: serviceName,
        serverTimestamp: serverTimestamp,
        errorMessage: 'Chưa có phiên đăng nhập hợp lệ',
      );
    }

    // 2. Query places
    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminPlacesEndpoint}?page=0&size=1',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) {
          placesCount = total.toInt();
        } else if (res['content'] is List) {
          placesCount = (res['content'] as List).length;
        }
      }
    } catch (_) {
      // Keep fallback
    }

    // 3. Query community posts
    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminCommunityPostsEndpoint}?page=0&size=5',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) {
          postsCount = total.toInt();
        }
        if (res['content'] is List) {
          final list = res['content'] as List;
          recentPosts = list
              .map((item) => AdminPostModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (_) {
      // Keep fallback
    }

    // 4. Query pending reports
    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminCommunityReportsEndpoint}?status=PENDING&page=0&size=5',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) {
          pendingReportsCount = total.toInt();
        }
        if (res['content'] is List) {
          final list = res['content'] as List;
          recentReports = list
              .map((item) => AdminPostReportModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (_) {
      // Keep fallback
    }

    // 5. Query media assets
    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminMediaAssetsEndpoint}?page=0&size=1',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) {
          mediaAssetsCount = total.toInt();
        }
      }
    } catch (_) {
      // Keep fallback
    }

    return AdminDashboardData(
      placesCount: placesCount,
      postsCount: postsCount,
      pendingReportsCount: pendingReportsCount,
      mediaAssetsCount: mediaAssetsCount,
      healthStatus: healthStatus,
      serviceName: serviceName,
      serverTimestamp: serverTimestamp,
      recentPendingReports: recentReports,
      recentPosts: recentPosts,
    );
  }
}
