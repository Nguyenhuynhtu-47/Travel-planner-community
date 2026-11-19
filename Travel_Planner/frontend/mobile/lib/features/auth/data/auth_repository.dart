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

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.googleAuthEndpoint,
      body: {
        'idToken': idToken,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> linkGoogle({
    required String token,
    required String idToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.googleLinkEndpoint,
      token: token,
      body: {
        'idToken': idToken,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.verifyEmailEndpoint,
      body: {
        'email': email,
        'code': code,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resendVerification({
    required String email,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.resendVerificationEndpoint,
      body: {
        'email': email,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.forgotPasswordEndpoint,
      body: {
        'email': email,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.verifyResetOtpEndpoint,
      body: {
        'email': email,
        'otp': otp,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    String? otp,
    String? resetToken,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'newPassword': newPassword,
      'confirmPassword': ?confirmPassword,
      if (resetToken != null && resetToken.isNotEmpty) 'resetToken': resetToken,
      if (otp != null && otp.isNotEmpty) 'otp': otp,
    };
    final response = await _apiClient.post(
      ApiConstants.resetPasswordEndpoint,
      body: body,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.changePasswordEndpoint,
      token: token,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
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

  Future<void> logout(String token) async {
    await _apiClient.post(
      ApiConstants.logoutEndpoint,
      token: token,
      body: {},
    );
  }

  Future<List<Map<String, dynamic>>> getSessions(String token) async {
    final response = await _apiClient.get(
      ApiConstants.sessionsEndpoint,
      token: token,
    );
    if (response is List) {
      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  Future<void> revokeSession({
    required String token,
    required String sessionId,
  }) async {
    await _apiClient.post(
      ApiConstants.revokeSessionEndpoint(sessionId),
      token: token,
      body: {},
    );
  }

  Future<int> revokeOtherSessions(String token) async {
    final response = await _apiClient.post(
      ApiConstants.revokeOtherSessionsEndpoint,
      token: token,
      body: {},
    );
    if (response is Map && response['revokedCount'] is num) {
      return (response['revokedCount'] as num).toInt();
    }
    return 0;
  }

  Future<int> revokeAllSessions(String token) async {
    final response = await _apiClient.post(
      ApiConstants.revokeAllSessionsEndpoint,
      token: token,
      body: {},
    );
    if (response is Map && response['revokedCount'] is num) {
      return (response['revokedCount'] as num).toInt();
    }
    return 0;
  }

  Future<Map<String, dynamic>> requestEmailChange({
    required String token,
    required String newEmail,
    String? password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.emailChangeRequestEndpoint,
      token: token,
      body: {
        'newEmail': newEmail,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyEmailChange({
    required String token,
    required String newEmail,
    required String otp,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.emailChangeVerifyEndpoint,
      token: token,
      body: {
        'newEmail': newEmail,
        'otp': otp,
      },
    );
    return response as Map<String, dynamic>;
  }
}
