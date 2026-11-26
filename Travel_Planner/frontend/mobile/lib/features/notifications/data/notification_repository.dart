import '../../../core/network/api_client.dart';
import 'models/notification_item.dart';

class NotificationRepository {
  final ApiClient _api;

  NotificationRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  Future<NotificationPage> getPage(
    String token, {
    String? cursor,
    int size = 20,
  }) async {
    final response = await _api.get(
      '/api/notifications',
      token: token,
      queryParameters: {'cursor': cursor, 'size': size},
    );
    if (response is! Map) {
      throw const FormatException('Phản hồi danh sách thông báo không hợp lệ');
    }
    return NotificationPage.fromJson(Map<String, dynamic>.from(response));
  }

  Future<int> getUnreadCount(String token) async {
    return (await getUnreadSummary(token)).count;
  }

  Future<NotificationUnreadSummary> getUnreadSummary(String token) async {
    final response = await _api.get(
      '/api/notifications/unread-count',
      token: token,
    );
    if (response is! Map || response['count'] is! num) {
      throw const FormatException(
        'Phản hồi số thông báo chưa đọc không hợp lệ',
      );
    }
    return NotificationUnreadSummary.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> markRead(int id, String token) async {
    await _api.post(
      '/api/notifications/$id/read',
      body: const {},
      token: token,
    );
  }

  Future<void> markAnnouncementRead(int id, String token) async {
    await _api.post(
      '/api/announcements/$id/read',
      body: const {},
      token: token,
    );
  }

  Future<void> markAllRead(String token) async {
    await _api.post(
      '/api/notifications/read-all',
      body: const {},
      token: token,
    );
  }
}
