import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.registerEndpoint,
      body: {
        'username': username,
        'email': email,
        'password': password,
        'fullName': fullName,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.loginEndpoint,
      body: {'usernameOrEmail': usernameOrEmail, 'password': password},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    final response = await _apiClient.get(
      ApiConstants.meEndpoint,
      token: token,
    );
    return response as Map<String, dynamic>;
  }
}
