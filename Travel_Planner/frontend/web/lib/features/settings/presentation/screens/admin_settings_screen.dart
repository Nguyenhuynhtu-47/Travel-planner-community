import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/system_setting_model.dart';
import '../../data/settings_repository.dart';

/// Phase 6 (IDs 7.4, 7.5, 7.6): Dynamic System Settings & Maintenance Mode Control.
class AdminSettingsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final SettingsRepository? repository;
  final bool embedded;

  const AdminSettingsScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final SettingsRepository _repository;

  List<SystemSettingModel> _settings = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _fieldErrors = {};
  final Set<String> _savingKeys = {};

  bool _isLoading = true;
  String? _loadError;

  bool get _isAdmin =>
      widget.authNotifier.currentUser?['role']?.toString().toUpperCase() ==
      'ADMIN';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SettingsRepository();
    if (_isAdmin) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await _repository.getSettings(
        token: widget.authNotifier.token,
      );
      if (!mounted) return;
      setState(() {
        _settings = list;
        for (final s in list) {
          _controllers.putIfAbsent(
            s.settingKey,
            () => TextEditingController(text: s.settingValue),
          );
          _controllers[s.settingKey]!.text = s.settingValue;
          _fieldErrors[s.settingKey] = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String? _validateValue(SystemSettingModel setting, String value) {
    final trimmed = value.trim();
    switch (setting.settingKey) {
      case 'MODERATION_AUTO_HIDE_THRESHOLD':
        final parsed = int.tryParse(trimmed);
        if (parsed == null || parsed < 1 || parsed > 50) {
          return 'Vui lòng nhập số nguyên từ 1 đến 50.';
        }
        return null;
      case 'GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD':
        final parsed = double.tryParse(trimmed);
        if (parsed == null || parsed < 0.50 || parsed > 1.00) {
          return 'Vui lòng nhập số thập phân từ 0.50 đến 1.00.';
        }
        return null;
      case 'MEDIA_MAX_IMAGE_SIZE_MB':
        final parsed = int.tryParse(trimmed);
        if (parsed == null || parsed < 1 || parsed > 5) {
          return 'Giá trị phải từ 1 đến 5 MB (giới hạn Servlet container 5MB).';
        }
        return null;
      case 'SYSTEM_MAINTENANCE_MESSAGE':
        if (trimmed.isEmpty || trimmed.length > 255) {
          return 'Thông điệp bảo trì phải từ 1 đến 255 ký tự.';
        }
        return null;
      default:
        if (trimmed.isEmpty) {
          return 'Giá trị không được để trống.';
        }
        return null;
    }
  }

  Future<void> _saveSetting(
    SystemSettingModel setting, {
    String? overrideValue,
    String? reason,
  }) async {
    final valueToSave =
        overrideValue ?? (_controllers[setting.settingKey]?.text ?? '');
    final validationError = _validateValue(setting, valueToSave);
    if (validationError != null) {
      setState(() {
        _fieldErrors[setting.settingKey] = validationError;
      });
      return;
    }

    setState(() {
      _fieldErrors[setting.settingKey] = null;
      _savingKeys.add(setting.settingKey);
    });

    try {
      final updated = await _repository.updateSetting(
        key: setting.settingKey,
        settingValue: valueToSave.trim(),
        reason: reason,
        token: widget.authNotifier.token,
      );
      if (!mounted) return;
      setState(() {
        final idx = _settings
            .indexWhere((s) => s.settingKey == updated.settingKey);
        if (idx >= 0) {
          _settings[idx] = updated;
        }
        _controllers[updated.settingKey]?.text = updated.settingValue;
        _savingKeys.remove(setting.settingKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu cấu hình ${updated.settingKey}.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _fieldErrors[setting.settingKey] = msg;
        _savingKeys.remove(setting.settingKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật ${setting.settingKey}: $msg'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleMaintenanceToggle(
    SystemSettingModel setting,
    bool targetValue,
  ) async {
    if (targetValue) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'Xác nhận bật Chế độ Bảo trì',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: const Text(
            'Khi bật chế độ bảo trì toàn hệ thống, tất cả người dùng thông thường và request chưa xác thực sẽ nhận mã HTTP 503. Tài khoản ADMIN vẫn truy cập bình thường.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận bật bảo trì'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _saveSetting(
      setting,
      overrideValue: targetValue ? 'true' : 'false',
      reason: targetValue
          ? 'Bật chế độ bảo trì từ Admin Portal'
          : 'Tắt chế độ bảo trì từ Admin Portal',
    );
  }

  String _groupTitle(String group) {
    switch (group.toUpperCase()) {
      case 'MODERATION':
        return 'Chính sách Kiểm duyệt Cộng đồng';
      case 'GEO':
        return 'Chuẩn hóa Địa lý';
      case 'MEDIA':
        return 'Giới hạn Tài nguyên Nghiệp vụ';
      case 'MAINTENANCE':
        return 'Chế độ Bảo trì Toàn hệ thống';
      default:
        return group;
    }
  }

  String _settingLabel(String key) {
    switch (key) {
      case 'MODERATION_AUTO_HIDE_THRESHOLD':
        return 'Ngưỡng báo cáo tự động ẩn bài viết (1 - 50)';
      case 'GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD':
        return 'Ngưỡng độ tin cậy tự động liên kết địa giới (0.50 - 1.00)';
      case 'MEDIA_MAX_IMAGE_SIZE_MB':
        return 'Dung lượng ảnh tối đa (1 - 5 MB)';
      case 'SYSTEM_MAINTENANCE_MODE':
        return 'Trạng thái bảo trì hệ thống';
      case 'SYSTEM_MAINTENANCE_MESSAGE':
        return 'Thông điệp thông báo bảo trì';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 52, color: AppColors.error),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Truy cập bị từ chối',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Bạn cần quyền Quản trị viên (ADMIN) để xem và thay đổi cài đặt hệ thống.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Cài đặt hệ thống',
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Làm mới'),
                onPressed: _isLoading ? null : _loadSettings,
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          margin: const EdgeInsets.all(AppSpacing.xl),
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 36),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Không thể tải cấu hình hệ thống: $_loadError',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Thử lại'),
                                onPressed: _loadSettings,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _settings.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có cấu hình hệ thống nào.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : _buildSettingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    final Map<String, List<SystemSettingModel>> grouped = {};
    for (final s in _settings) {
      grouped.putIfAbsent(s.settingGroup, () => []).add(s);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: grouped.entries.map((entry) {
          final group = entry.key;
          final items = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _groupTitle(group),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (group.toUpperCase() == 'MEDIA') ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Lưu ý kỹ thuật: Giới hạn Servlet Multipart tối đa là 5MB (cố định ở mức JVM). Ngưỡng nghiệp vụ không được vượt quá 5MB.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ...items.map(_buildSettingRow),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingRow(SystemSettingModel setting) {
    final isSaving = _savingKeys.contains(setting.settingKey);
    final errorText = _fieldErrors[setting.settingKey];
    final isBool = setting.valueType.toUpperCase() == 'BOOLEAN';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _settingLabel(setting.settingKey),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (setting.description != null &&
                        setting.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        setting.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isBool)
                Row(
                  children: [
                    Text(
                      setting.boolValue ? 'Đang bảo trì' : 'Hoạt động',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: setting.boolValue
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: setting.boolValue,
                      onChanged: isSaving
                          ? null
                          : (val) => _handleMaintenanceToggle(setting, val),
                    ),
                  ],
                ),
            ],
          ),
          if (!isBool) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('setting_input_${setting.settingKey}'),
                    controller: _controllers[setting.settingKey],
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      fillColor: AppColors.surface,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                ElevatedButton.icon(
                  key: ValueKey('setting_save_${setting.settingKey}'),
                  icon: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Lưu cấu hình'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving ? null : () => _saveSetting(setting),
                ),
              ],
            ),
          ],
          if (setting.updatedBy != null && setting.updatedBy!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Cập nhật gần nhất bởi: ${setting.updatedBy}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
