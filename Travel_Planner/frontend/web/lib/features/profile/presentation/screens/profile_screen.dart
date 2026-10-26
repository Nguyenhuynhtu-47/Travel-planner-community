import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const ProfileScreen({super.key, required this.authNotifier});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _avatarController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _repository = ProfileRepository();

  Map<String, dynamic>? _profile;
  Map<String, String>? _validationErrors;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  Future<void> _logout() async {
    await widget.authNotifier.logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _avatarController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillFields(Map<String, dynamic> profile) {
    _fullNameController.text = profile['fullName']?.toString() ?? '';
    _avatarController.text = profile['avatar']?.toString() ?? '';
    _phoneController.text = profile['phone']?.toString() ?? '';
    _addressController.text = profile['address']?.toString() ?? '';
    _bioController.text = profile['bio']?.toString() ?? '';
  }

  Future<void> _loadProfile() async {
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _repository.getProfile(token);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fillFields(profile);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _logout();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải hồ sơ. Vui lòng thử lại.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() {
      _saving = true;
      _validationErrors = null;
    });

    try {
      final profile = await _repository.updateProfile(token, {
        'fullName': _fullNameController.text.trim(),
        'avatar': _avatarController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      await widget.authNotifier.updateCurrentUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fillFields(profile);
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã cập nhật hồ sơ',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _validationErrors = e.validationErrors;
      });
      if (e.statusCode == 401) {
        await _logout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể lưu hồ sơ. Vui lòng thử lại.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Chưa cập nhật';
    }
    return switch (value.toString()) {
      'USER' => 'Người dùng',
      'ADMIN' => 'Quản trị viên',
      'ACTIVE' => 'Đang hoạt động',
      'INACTIVE' => 'Đã vô hiệu hóa',
      'BANNED' => 'Đã khóa',
      _ => value.toString(),
    };
  }

  String? _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              key: ValueKey('profile_loading'),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? KeyedSubtree(
              key: const ValueKey('profile_error'),
              child: _errorView(),
            )
          : AnimatedSwitcher(
              duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: _editing
                  ? KeyedSubtree(
                      key: const ValueKey('profile_editor'),
                      child: _editor(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('profile_view'),
                      child: _profileView(),
                    ),
            ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _loadProfile,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        color: AppColors.surfaceStrong,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 52, color: AppColors.textSecondary),
    );
  }

  Widget _statusBadge(dynamic rawStatus, String statusText) {
    final statusStr = rawStatus?.toString();
    final (bgColor, borderColor, textColor) = switch (statusStr) {
      'ACTIVE' => (
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        const Color(0xFF047857),
      ),
      'BANNED' => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        AppColors.error,
      ),
      'INACTIVE' => (
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        const Color(0xFFB45309),
      ),
      _ => (AppColors.surfaceSoft, AppColors.border, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _profileView() {
    final profile = _profile!;
    final avatar = profile['avatar']?.toString() ?? '';
    final role = _value(profile['role']);
    final status = _value(profile['status']);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipOval(
                      child: avatar.startsWith('http')
                          ? Image.network(
                              avatar,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _defaultAvatar(),
                            )
                          : _defaultAvatar(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _value(profile['fullName']),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '@${profile['username'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _statusBadge(profile['status'], status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sectionHeader('Thông tin cá nhân'),
                  const SizedBox(height: 12),
                  _infoCard([
                    _detailRow('Họ và tên', profile['fullName']),
                    _detailRow('Số điện thoại', profile['phone']),
                    _detailRow('Địa chỉ', profile['address']),
                    _detailRow('Giới thiệu', profile['bio']),
                  ]),
                  const SizedBox(height: 24),
                  _sectionHeader('Thông tin tài khoản'),
                  const SizedBox(height: 12),
                  _infoCard([
                    _detailRow('Tên đăng nhập', profile['username']),
                    _detailRow('Email', profile['email']),
                    _detailRow('Vai trò', profile['role']),
                    _detailRow('Trạng thái tài khoản', profile['status']),
                    _detailRow(
                      'Ngày tham gia',
                      _formatDate(profile['createdAt']),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  AppPrimaryButton(
                    text: 'Chỉnh sửa hồ sơ',
                    onPressed: () => setState(() => _editing = true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _detailRow(String label, dynamic rawValue) {
    final value = _value(rawValue);
    final isUnset = value == 'Chưa cập nhật';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            softWrap: true,
            style: TextStyle(
              color: isUnset ? AppColors.mutedSoft : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Chỉnh sửa hồ sơ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cập nhật thông tin cá nhân và liên hệ của bạn',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      label: 'Họ và tên',
                      hint: 'Nhập họ và tên đầy đủ',
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      errorText: _validationErrors?['fullName'],
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập họ và tên'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Ảnh đại diện (URL)',
                      hint: 'https://example.com/avatar.jpg',
                      controller: _avatarController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      errorText: _validationErrors?['avatar'],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Số điện thoại',
                      hint: 'Ví dụ: 0912345678',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      errorText: _validationErrors?['phone'],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Địa chỉ',
                      hint: 'Ví dụ: TP. Hồ Chí Minh, Việt Nam',
                      controller: _addressController,
                      textInputAction: TextInputAction.next,
                      errorText: _validationErrors?['address'],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Giới thiệu',
                      hint: 'Chia sẻ ngắn về sở thích du lịch của bạn...',
                      controller: _bioController,
                      maxLines: 3,
                      minLines: 2,
                      textInputAction: TextInputAction.newline,
                      errorText: _validationErrors?['bio'],
                    ),
                    const SizedBox(height: 28),
                    AppPrimaryButton(
                      text: 'Lưu thay đổi',
                      isLoading: _saving,
                      onPressed: _saveProfile,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              _fillFields(_profile!);
                              setState(() => _editing = false);
                            },
                      child: const Text('Hủy'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
