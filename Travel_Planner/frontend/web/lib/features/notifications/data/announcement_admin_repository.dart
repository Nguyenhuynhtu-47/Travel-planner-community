import 'package:travel_planner_web/core/network/api_client.dart';

class AnnouncementAdminRepository {
  final ApiClient _api;
  AnnouncementAdminRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> list(
    String token, {
    int page = 0,
    int size = 20,
    String? status,
    String? type,
    String? query,
  }) async {
    final parameters = <String, String>{
      'page': '$page',
      'size': '$size',
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
    };
    final path = Uri(
      path: '/api/admin/announcements',
      queryParameters: parameters,
    ).toString();
    final response = await _api.get(path, token: token);
    if (response is! Map) {
      throw const FormatException(
        'Phản hồi danh sách announcement không hợp lệ',
      );
    }
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, int>> summary(String token) async {
    final response = await _api.get(
      '/api/admin/announcements/summary',
      token: token,
    );
    if (response is! Map) {
      throw const FormatException(
        'Phản hồi thống kê announcement không hợp lệ',
      );
    }
    return response.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  Future<void> create(String token, Map<String, dynamic> body) async {
    await _api.post('/api/admin/announcements', body: body, token: token);
  }

  Future<void> update(String token, int id, Map<String, dynamic> body) async {
    await _api.put('/api/admin/announcements/$id', body: body, token: token);
  }

  Future<void> publish(String token, int id) async {
    await _api.post(
      '/api/admin/announcements/$id/publish',
      body: const {},
      token: token,
    );
  }

  Future<void> cancel(String token, int id) async {
    await _api.post(
      '/api/admin/announcements/$id/cancel',
      body: const {},
      token: token,
    );
  }
}
