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

  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
  static const String meEndpoint = '/api/auth/me';
  static const String currentProfileEndpoint = '/api/user/profile';
  static const String healthEndpoint = '/api/health';
  static const String placesEndpoint = '/api/places';
  static const String adminPlacesEndpoint = '/api/admin/places';
  static String adminPlaceDetailEndpoint(int id) => '/api/admin/places/$id';
  static const String adminCommunityPostsEndpoint = '/api/admin/community/posts';
  static String adminCommunityPostDetailEndpoint(int id) => '/api/admin/community/posts/$id';
  static String adminCommunityPostPurgeEndpoint(int id) => '/api/admin/community/posts/$id/purge';
  static const String adminCommunityReportsEndpoint = '/api/admin/community/reports';
  static String adminCommunityReportDetailEndpoint(int id) => '/api/admin/community/reports/$id';
  static const String adminCommunityMediaAssetsEndpoint = '/api/admin/community/media-assets';
  static String adminCommunityMediaAssetRetryEndpoint(int id) => '/api/admin/community/media-assets/$id/retry';
}
