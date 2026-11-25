import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_storage.dart';
import 'models/system_setting_model.dart';

/// Repository for Admin System Settings (IDs 7.4 - 7.6).
class SettingsRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  SettingsRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<String?> _resolveToken(String? token) async {
    return token ?? await _authStorage.getToken();
  }

  Future<List<SystemSettingModel>> getSettings({String? token}) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.get(
      ApiConstants.adminSettingsEndpoint,
      token: effectiveToken,
    );
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(SystemSettingModel.fromJson)
          .toList();
    }
    throw Exception('Phản hồi danh sách cấu hình hệ thống không hợp lệ.');
  }

  Future<SystemSettingModel> updateSetting({
    required String key,
    required String settingValue,
    String? reason,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final response = await _apiClient.put(
      ApiConstants.adminSettingUpdateEndpoint(Uri.encodeComponent(key)),
      body: {
        'settingValue': settingValue,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      token: effectiveToken,
    );
    if (response is Map<String, dynamic>) {
      return SystemSettingModel.fromJson(response);
    }
    throw Exception('Phản hồi cập nhật cấu hình không hợp lệ.');
  }
}
