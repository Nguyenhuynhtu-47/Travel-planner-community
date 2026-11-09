import '../../../core/network/api_client.dart';
import '../../explore/data/models/page_result.dart';
import '../../explore/data/models/itinerary_summary.dart';
import 'models/public_profile.dart';
import 'models/public_user_summary.dart';

class PublicProfileRepository {
  final ApiClient _api;
  PublicProfileRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  String _base(int id) => '/api/users/$id';

  Future<PublicProfile> getProfile(int id, {String? token}) async {
    final value = await _api.get('${_base(id)}/public-profile', token: token);
    if (value is Map) {
      return PublicProfile.fromJson(Map<String, dynamic>.from(value));
    }
    throw Exception('Thông tin hồ sơ không hợp lệ.');
  }

  Future<void> follow(int id, String token) async =>
      _api.post('${_base(id)}/follow', body: const {}, token: token);
  Future<void> unfollow(int id, String token) async =>
      _api.delete('${_base(id)}/follow', token: token);

  Future<PageResult<ItinerarySummary>> itineraries(
    int id, {
    int page = 0,
    String? token,
  }) async {
    final value = await _api.get(
      '${_base(id)}/itineraries',
      queryParameters: {'page': page, 'size': 10},
      token: token,
    );
    if (value is Map) {
      return PageResult<ItinerarySummary>.fromJson(
        Map<String, dynamic>.from(value),
        (item) =>
            ItinerarySummary.fromJson(Map<String, dynamic>.from(item as Map)),
      );
    }
    throw Exception('Danh sách lịch trình không hợp lệ.');
  }

  Future<PageResult<PublicUserSummary>> users(
    int id, {
    required bool followers,
    int page = 0,
    String? token,
  }) async {
    final value = await _api.get(
      '${_base(id)}/${followers ? 'followers' : 'following'}',
      queryParameters: {'page': page, 'size': 20},
      token: token,
    );
    if (value is Map) {
      return PageResult<PublicUserSummary>.fromJson(
        Map<String, dynamic>.from(value),
        (item) =>
            PublicUserSummary.fromJson(Map<String, dynamic>.from(item as Map)),
      );
    }
    throw Exception('Danh sách người dùng không hợp lệ.');
  }
}
