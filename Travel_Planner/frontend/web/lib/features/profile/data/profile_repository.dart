import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _apiClient.get(
      ApiConstants.currentProfileEndpoint,
      token: token,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> profile,
  ) async {
    final response = await _apiClient.put(
      ApiConstants.currentProfileEndpoint,
      token: token,
      body: profile,
    );
    return response as Map<String, dynamic>;
  }
}
