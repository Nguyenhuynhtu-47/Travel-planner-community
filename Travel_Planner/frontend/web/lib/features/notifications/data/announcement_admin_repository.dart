import 'package:travel_planner_web/core/network/api_client.dart';

class AnnouncementAdminRepository {
  final ApiClient _api;
  AnnouncementAdminRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> list(
    String token, {
    int page = 0,
    String? status,
    String? query,
  }) async {
    final response = await _api.get(
      '/api/admin/announcements?page=$page&size=20'
      '${status == null ? '' : '&status=$status'}${query == null || query.isEmpty ? '' : '&query=${Uri.encodeQueryComponent(query)}'}',
      token: token,
    );
    if (response is! Map) {
      throw const FormatException(
        'Phản hồi danh sách announcement không hợp lệ',
      );
    }
    return Map<String, dynamic>.from(response);
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
