import 'package:travel_planner_web/core/constants/api_constants.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/features/audit_logs/data/models/audit_log_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_report_model.dart';

class DashboardTimeSeriesPoint {
  final String label;
  final int count;

  const DashboardTimeSeriesPoint({
    required this.label,
    required this.count,
  });

  factory DashboardTimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return DashboardTimeSeriesPoint(
      label: json['label']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardTopPlaceItem {
  final int placeId;
  final String name;
  final String? category;
  final String? areaName;
  final int itineraryCount;

  const DashboardTopPlaceItem({
    required this.placeId,
    required this.name,
    this.category,
    this.areaName,
    required this.itineraryCount,
  });

  factory DashboardTopPlaceItem.fromJson(Map<String, dynamic> json) {
    return DashboardTopPlaceItem(
      placeId: (json['placeId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString(),
      areaName: json['areaName']?.toString(),
      itineraryCount: (json['itineraryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardData {
  // 6 Core Operational Metric Groups (Phase 7 ID 7.7)
  final int totalUsers;
  final int activeUsers;
  final int bannedUsers;

  final int placesCount;
  final int activePlaces;
  final int linkedPlaces;
  final double placeAreaCoveragePercentage;

  final int totalItineraries;
  final int publicItineraries;
  final int privateItineraries;
  final int activeItineraries;
  final int hiddenItineraries;

  final int postsCount;
  final int hiddenPosts;

  final int pendingReportsCount;

  final int mediaAssetsCount;
  final int deadLetterMediaAssets;

  final String healthStatus;
  final String? serviceName;
  final String? serverTimestamp;

  // Analytics & Recent Audit Stream (Phase 7 ID 7.8)
  final int analyticsDays;
  final String? analyticsFromDate;
  final String? analyticsToDate;
  final List<DashboardTimeSeriesPoint> userRegistrationsDaily;
  final List<DashboardTimeSeriesPoint> communityPostsWeekly;
  final List<DashboardTopPlaceItem> topPlaces;
  final List<AuditLogModel> recentAuditLogs;

  // Legacy operational lists (used if fallback mode is active)
  final List<AdminPostReportModel> recentPendingReports;
  final List<AdminPostModel> recentPosts;
  final String? errorMessage;

  const AdminDashboardData({
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.bannedUsers = 0,
    required this.placesCount,
    this.activePlaces = 0,
    this.linkedPlaces = 0,
    this.placeAreaCoveragePercentage = 0.0,
    this.totalItineraries = 0,
    this.publicItineraries = 0,
    this.privateItineraries = 0,
    this.activeItineraries = 0,
    this.hiddenItineraries = 0,
    required this.postsCount,
    this.hiddenPosts = 0,
    required this.pendingReportsCount,
    required this.mediaAssetsCount,
    this.deadLetterMediaAssets = 0,
    required this.healthStatus,
    this.serviceName,
    this.serverTimestamp,
    this.analyticsDays = 30,
    this.analyticsFromDate,
    this.analyticsToDate,
    this.userRegistrationsDaily = const [],
    this.communityPostsWeekly = const [],
    this.topPlaces = const [],
    this.recentAuditLogs = const [],
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

  Future<AdminDashboardData> fetchDashboardData(
    String? token, {
    int days = 30,
  }) async {
    if (token == null || token.isEmpty) {
      String healthStatus = 'UNKNOWN';
      try {
        final res = await _apiClient.get(ApiConstants.healthEndpoint);
        if (res is Map<String, dynamic>) {
          healthStatus = res['status']?.toString() ?? 'UP';
        }
      } catch (_) {
        healthStatus = 'UNAVAILABLE';
      }
      return AdminDashboardData(
        placesCount: 0,
        postsCount: 0,
        pendingReportsCount: 0,
        mediaAssetsCount: 0,
        healthStatus: healthStatus,
        errorMessage: 'Chưa có phiên đăng nhập hợp lệ',
      );
    }

    // Try Phase 7 unified summary endpoint first (single request)
    try {
      final summaryRes = await _apiClient.get(
        ApiConstants.adminDashboardSummaryEndpoint,
        token: token,
      );

      if (summaryRes is Map<String, dynamic>) {
        Map<String, dynamic>? analyticsRes;
        try {
          final rawAnalytics = await _apiClient.get(
            '${ApiConstants.adminDashboardAnalyticsEndpoint}?days=$days',
            token: token,
          );
          if (rawAnalytics is Map<String, dynamic>) {
            analyticsRes = rawAnalytics;
          }
        } catch (_) {
          // Keep empty analytics if analytics endpoint fails independently
        }

        return AdminDashboardData(
          totalUsers: (summaryRes['totalUsers'] as num?)?.toInt() ?? 0,
          activeUsers: (summaryRes['activeUsers'] as num?)?.toInt() ?? 0,
          bannedUsers: (summaryRes['bannedUsers'] as num?)?.toInt() ?? 0,
          placesCount: (summaryRes['totalPlaces'] as num?)?.toInt() ?? 0,
          activePlaces: (summaryRes['activePlaces'] as num?)?.toInt() ?? 0,
          linkedPlaces: (summaryRes['linkedPlaces'] as num?)?.toInt() ?? 0,
          placeAreaCoveragePercentage:
              (summaryRes['placeAreaCoveragePercentage'] as num?)?.toDouble() ??
                  0.0,
          totalItineraries:
              (summaryRes['totalItineraries'] as num?)?.toInt() ?? 0,
          publicItineraries:
              (summaryRes['publicItineraries'] as num?)?.toInt() ?? 0,
          privateItineraries:
              (summaryRes['privateItineraries'] as num?)?.toInt() ?? 0,
          activeItineraries:
              (summaryRes['activeItineraries'] as num?)?.toInt() ?? 0,
          hiddenItineraries:
              (summaryRes['hiddenItineraries'] as num?)?.toInt() ?? 0,
          postsCount: (summaryRes['totalPosts'] as num?)?.toInt() ?? 0,
          hiddenPosts: (summaryRes['hiddenPosts'] as num?)?.toInt() ?? 0,
          pendingReportsCount:
              (summaryRes['pendingReportsCount'] as num?)?.toInt() ?? 0,
          mediaAssetsCount:
              (summaryRes['totalMediaAssets'] as num?)?.toInt() ?? 0,
          deadLetterMediaAssets:
              (summaryRes['deadLetterMediaAssets'] as num?)?.toInt() ?? 0,
          healthStatus: summaryRes['healthStatus']?.toString() ?? 'UP',
          serverTimestamp: summaryRes['serverTimestamp']?.toString(),
          analyticsDays: (analyticsRes?['days'] as num?)?.toInt() ?? days,
          analyticsFromDate: analyticsRes?['fromDate']?.toString(),
          analyticsToDate: analyticsRes?['toDate']?.toString(),
          userRegistrationsDaily: analyticsRes?['userRegistrationsDaily'] is List
              ? (analyticsRes!['userRegistrationsDaily'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(DashboardTimeSeriesPoint.fromJson)
                  .toList()
              : const [],
          communityPostsWeekly: analyticsRes?['communityPostsWeekly'] is List
              ? (analyticsRes!['communityPostsWeekly'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(DashboardTimeSeriesPoint.fromJson)
                  .toList()
              : const [],
          topPlaces: analyticsRes?['topPlaces'] is List
              ? (analyticsRes!['topPlaces'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(DashboardTopPlaceItem.fromJson)
                  .toList()
              : const [],
          recentAuditLogs: analyticsRes?['recentAuditLogs'] is List
              ? (analyticsRes!['recentAuditLogs'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(AuditLogModel.fromJson)
                  .toList()
              : const [],
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
      // Fall back to legacy multi-endpoint fetch if /summary is not mocked (404)
    }

    return _fetchLegacyDashboardData(token);
  }

  Future<AdminDashboardData> _fetchLegacyDashboardData(String token) async {
    int placesCount = 0;
    int postsCount = 0;
    int pendingReportsCount = 0;
    int mediaAssetsCount = 0;
    String healthStatus = 'UNKNOWN';
    String? serviceName;
    String? serverTimestamp;
    List<AdminPostReportModel> recentReports = [];
    List<AdminPostModel> recentPosts = [];

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

    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminPlacesEndpoint}?page=0&size=1',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) placesCount = total.toInt();
      }
    } catch (_) {}

    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminCommunityPostsEndpoint}?page=0&size=5',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) postsCount = total.toInt();
        if (res['content'] is List) {
          recentPosts = (res['content'] as List)
              .map((item) => AdminPostModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (_) {}

    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminCommunityReportsEndpoint}?status=PENDING&page=0&size=5',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) pendingReportsCount = total.toInt();
        if (res['content'] is List) {
          recentReports = (res['content'] as List)
              .map((item) => AdminPostReportModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (_) {}

    try {
      final res = await _apiClient.get(
        '${ApiConstants.adminMediaAssetsEndpoint}?page=0&size=1',
        token: token,
      );
      if (res is Map<String, dynamic>) {
        final total = res['totalElements'];
        if (total is num) mediaAssetsCount = total.toInt();
      }
    } catch (_) {}

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
