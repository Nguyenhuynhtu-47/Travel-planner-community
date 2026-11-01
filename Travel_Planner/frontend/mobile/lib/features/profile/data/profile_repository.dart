import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ProfileRepository {
  final ApiClient _apiClient;
  ProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getProfile(String token) async =>
      await _apiClient.get(ApiConstants.currentProfileEndpoint, token: token)
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> profile,
  ) async => await _apiClient.put(
    ApiConstants.currentProfileEndpoint,
    token: token,
    body: profile,
  ) as Map<String, dynamic>;

  Future<String> uploadImage(
    String token, {
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _apiClient.uploadFile(
      ApiConstants.imageUploadEndpoint,
      bytes: bytes,
      filename: filename,
      token: token,
    );
    if (response is Map && response['secureUrl'] is String) {
      return response['secureUrl'] as String;
    }
    throw ApiException(
      statusCode: 0,
      message: 'Phản hồi upload ảnh không hợp lệ.',
    );
  }
}
