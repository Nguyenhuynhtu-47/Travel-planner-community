class ApiConstants {
  // Override at build/run time with --dart-define=API_BASE_URL=<URL>.
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    return 'http://localhost:8080';
  }

  static const String loginEndpoint = '/api/auth/login';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String meEndpoint = '/api/auth/me';
  static const String currentProfileEndpoint = '/api/user/profile';
  static const String healthEndpoint = '/api/health';
  static const String placesEndpoint = '/api/places';
  static const String adminUsersEndpoint = '/api/admin/users';
  static String adminUserDetailEndpoint(int id) => '/api/admin/users/$id';
  static String adminUserStatusEndpoint(int id) => '/api/admin/users/$id/status';
  static String adminUserRoleEndpoint(int id) => '/api/admin/users/$id/role';
  static String adminUserRevokeSessionsEndpoint(int id) => '/api/admin/users/$id/sessions/revoke-all';
  static const String adminItinerariesEndpoint = '/api/admin/itineraries';
  static String adminItineraryDetailEndpoint(int id) => '/api/admin/itineraries/$id';
  static String adminItineraryModerateEndpoint(int id) => '/api/admin/itineraries/$id/moderate';
  static const String adminPlacesEndpoint = '/api/admin/places';
  static String adminPlaceDetailEndpoint(int id) => '/api/admin/places/$id';
  static const String administrativeAreasProvincesEndpoint = '/api/administrative-areas/provinces';
  static String administrativeAreaChildrenEndpoint(String code) => '/api/administrative-areas/$code/children';
  static const String administrativeAreasSearchEndpoint = '/api/administrative-areas/search';
  static const String adminPlaceAdminAreaStatsEndpoint = '/api/admin/places/administrative-area/stats';
  static const String adminPlaceAdminAreaBatchResolveEndpoint = '/api/admin/places/administrative-area/batch-resolve';
  static String adminPlaceAdminAreaPreviewEndpoint(int id) => '/api/admin/places/$id/administrative-area/preview';
  static String adminPlaceAdminAreaResolveEndpoint(int id) => '/api/admin/places/$id/administrative-area/resolve';
  static String adminPlaceAdminAreaLinkEndpoint(int id) => '/api/admin/places/$id/administrative-area/link';
  static String adminPlaceAdminAreaUnlinkEndpoint(int id) => '/api/admin/places/$id/administrative-area';
  static const String adminAuditLogsEndpoint = '/api/admin/audit-logs';
  static String adminAuditLogDetailEndpoint(int id) => '/api/admin/audit-logs/$id';
  static const String adminAuditLogActionTypesEndpoint = '/api/admin/audit-logs/action-types';
  static const String adminSettingsEndpoint = '/api/admin/settings';
  static String adminSettingUpdateEndpoint(String key) => '/api/admin/settings/$key';
  static const String adminDashboardSummaryEndpoint = '/api/admin/dashboard/summary';
  static const String adminDashboardAnalyticsEndpoint = '/api/admin/dashboard/analytics';
  static const String adminCommunityPostsEndpoint = '/api/admin/community/posts';
  static String adminCommunityPostDetailEndpoint(int id) => '/api/admin/community/posts/$id';
  static String adminCommunityPostModerateEndpoint(int id) => '/api/admin/community/posts/$id/moderate';
  static String adminCommunityPostPurgeEndpoint(int id) => '/api/admin/community/posts/$id/purge';
  static const String adminCommunityReportsEndpoint = '/api/admin/community/reports';
  static String adminCommunityReportDetailEndpoint(int id) => '/api/admin/community/reports/$id';
  static String adminCommunityReportResolveEndpoint(int id) => '/api/admin/community/reports/$id/resolve';
  static const String adminMediaAssetsEndpoint = '/api/admin/media-assets';
  static String adminMediaAssetRetryEndpoint(int id) => '/api/admin/media-assets/$id/retry';

  // Backward-compatible aliases
  static const String adminCommunityMediaAssetsEndpoint = adminMediaAssetsEndpoint;
  static String adminCommunityMediaAssetRetryEndpoint(int id) => adminMediaAssetRetryEndpoint(id);
}
