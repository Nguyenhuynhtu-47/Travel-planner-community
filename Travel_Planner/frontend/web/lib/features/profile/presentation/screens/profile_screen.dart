import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final bool embedded;
  final ProfileRepository? repository;

  const ProfileScreen({
    super.key,
    required this.authNotifier,
    this.embedded = false,
    this.repository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _avatarController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();
  final _avatarFocusNode = FocusNode();
  late final ProfileRepository _repository;

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
    _repository = widget.repository ?? ProfileRepository();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _handleController.dispose();
    _avatarController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    _avatarFocusNode.dispose();
    super.dispose();
  }

  void _fillFields(Map<String, dynamic> profile) {
    _fullNameController.text = profile['fullName']?.toString() ?? '';
    _handleController.text = profile['handle']?.toString() ?? '';
    _avatarController.text = profile['avatar']?.toString() ?? '';
    _phoneController.text = profile['phone']?.toString() ?? '';
    _addressController.text = profile['address']?.toString() ?? '';
    _bioController.text = profile['bio']?.toString() ?? '';
    _emailController.text = profile['email']?.toString() ?? '';
    _roleController.text = _value(profile['role']);
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
      final rawHandle = _handleController.text.trim().toLowerCase();
      final cleanHandle = rawHandle.startsWith('@')
          ? rawHandle.substring(1).trim()
          : rawHandle;
      final profile = await _repository.updateProfile(token, {
        'fullName': _fullNameController.text.trim(),
        'handle': cleanHandle,
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
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Hồ sơ cá nhân'),
              actions: [
                IconButton(
                  tooltip: 'Đăng xuất',
                  icon: const Icon(Icons.logout),
                  onPressed: _logout,
                ),
              ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.embedded)
            AdminPageHeader(
              title: _editing ? 'Chỉnh sửa hồ sơ' : 'Hồ sơ cá nhân',
              subtitle: _editing
                  ? 'Cập nhật thông tin cá nhân, ảnh đại diện và giới thiệu của tài khoản quản trị.'
                  : 'Quản lý thông tin cá nhân và chi tiết tài khoản trên Travel Planner Portal.',
            ),
          Expanded(
            child: _loading
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
                    duration:
                        MediaQuery.maybeOf(context)?.disableAnimations ?? false
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
          ),
        ],
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

  Widget _buildAvatarWidget(String avatarUrl, {double size = 100}) {
    final trimmed = avatarUrl.trim();
    final hasValidUrl =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
      ),
      child: ClipOval(
        child: hasValidUrl
            ? Image.network(
                trimmed,
                width: size - 6,
                height: size - 6,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _defaultAvatarContent(size - 6),
              )
            : _defaultAvatarContent(size - 6),
      ),
    );
  }

  Widget _defaultAvatarContent(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceStrong,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.54,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _statusBadge(dynamic rawStatus, String statusText) {
    final statusStr = rawStatus?.toString();
    final (bgColor, borderColor, textColor) = switch (statusStr) {
      'ACTIVE' => (
        AppColors.successLight,
        AppColors.successBorder,
        AppColors.success,
      ),
      'BANNED' => (
        AppColors.errorLight,
        AppColors.errorBorder,
        AppColors.error,
      ),
      'INACTIVE' => (
        AppColors.warningLight,
        AppColors.warningBorder,
        AppColors.warning,
      ),
      _ => (AppColors.surfaceSoft, AppColors.border, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: borderColor, width: 1),
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

  Widget _portalCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Material(
      color: AppColors.surface,
      elevation: 0.5,
      shadowColor: const Color(0x0F0F172A),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  Widget _buildSummaryCard({required bool isEditMode}) {
    final profile = _profile!;
    final displayAvatar = isEditMode
        ? _avatarController.text
        : (profile['avatar']?.toString() ?? '');
    final displayName = isEditMode && _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text.trim()
        : _value(profile['fullName']);
    final rawHandle = isEditMode
        ? _handleController.text.trim()
        : (profile['handle']?.toString().trim() ?? '');
    final cleanHandle =
        rawHandle.startsWith('@') ? rawHandle.substring(1) : rawHandle;
    final role = _value(profile['role']);
    final status = _value(profile['status']);
    final joinedDate = _formatDate(profile['createdAt']);

    final isAdminRole =
        profile['role']?.toString().toUpperCase() == 'ADMIN';

    return _portalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatarWidget(displayAvatar, size: 104),
                  if (isEditMode)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Tooltip(
                        message: 'Nhập URL ảnh đại diện',
                        child: InkWell(
                          onTap: () => _avatarFocusNode.requestFocus(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (cleanHandle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '@$cleanHandle',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _statusBadge(profile['status'], status),
                ],
              ),
              if (joinedDate != null) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tham gia từ $joinedDate',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tài khoản đã xác thực',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isAdminRole
                                  ? 'Quyền hạn: Toàn quyền quản trị hệ thống'
                                  : 'Quyền hạn: Người dùng hệ thống',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              if (!isEditMode) ...[
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    text: 'Chỉnh sửa hồ sơ',
                    onPressed: () => setState(() => _editing = true),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    onPressed: _logout,
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.edit_note_outlined,
                        size: 18,
                        color: Color(0xFFF43F5E),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang ở chế độ chỉnh sửa. Ảnh đại diện và tên sẽ xem trước trực tiếp.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileView() {
    final profile = _profile!;
    final handleValue = (profile['handle'] != null &&
            profile['handle'].toString().trim().isNotEmpty)
        ? '@${profile['handle'].toString().trim()}'
        : 'Chưa thiết lập';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _portalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _cardSectionTitle(
                          Icons.person_outline,
                          'Thông tin cá nhân',
                        ),
                        const SizedBox(height: 16),
                        _buildResponsiveTwoColFields(
                          [
                            _detailItem(
                              Icons.badge_outlined,
                              'Họ và tên',
                              profile['fullName'],
                            ),
                            _detailItem(
                              Icons.phone_outlined,
                              'Số điện thoại',
                              profile['phone'],
                            ),
                            _detailItem(
                              Icons.location_on_outlined,
                              'Địa chỉ',
                              profile['address'],
                            ),
                          ],
                          twoCols: isWide,
                        ),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _detailItem(
                          Icons.notes_outlined,
                          'Giới thiệu',
                          profile['bio'],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _portalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _cardSectionTitle(
                          Icons.verified_user_outlined,
                          'Thông tin tài khoản',
                        ),
                        const SizedBox(height: 16),
                        _buildResponsiveTwoColFields(
                          [
                            _detailItem(
                              Icons.alternate_email,
                              'Định danh (@handle)',
                              handleValue,
                            ),
                            _detailItem(
                              Icons.email_outlined,
                              'Email',
                              profile['email'],
                            ),
                            _detailItem(
                              Icons.admin_panel_settings_outlined,
                              'Vai trò',
                              profile['role'],
                            ),
                            _detailItem(
                              Icons.shield_outlined,
                              'Trạng thái tài khoản',
                              profile['status'],
                            ),
                            _detailItem(
                              Icons.calendar_today_outlined,
                              'Ngày tham gia',
                              _formatDate(profile['createdAt']),
                            ),
                          ],
                          twoCols: isWide,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 35,
                        child: _buildSummaryCard(isEditMode: false),
                      ),
                      const SizedBox(width: 24),
                      Expanded(flex: 65, child: rightColumn),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(isEditMode: false),
                  const SizedBox(height: 20),
                  rightColumn,
                ],
              );
            },
          ),
        );
      }

  Widget _cardSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFFF43F5E)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveTwoColFields(
    List<Widget> items, {
    required bool twoCols,
  }) {
    if (!twoCols) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items
            .map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: w,
              ),
            )
            .toList(),
      );
    }
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 16));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[i]),
            const SizedBox(width: 20),
            Expanded(
              child: i + 1 < items.length
                  ? items[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _detailItem(IconData icon, String label, dynamic rawValue) {
    final value = _value(rawValue);
    final isUnset = value == 'Chưa cập nhật';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.textMuted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                softWrap: true,
                style: TextStyle(
                  color: isUnset ? AppColors.mutedSoft : AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: isUnset ? FontWeight.w400 : FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820;
                final formColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _portalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _cardSectionTitle(
                            Icons.person_outline,
                            'Thông tin cá nhân',
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Cập nhật thông tin hiển thị và liên hệ cá nhân của bạn',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildResponsiveTwoColFields(
                            [
                              AppTextField(
                                label: 'Họ và tên',
                                hint: 'Nhập họ và tên đầy đủ',
                                controller: _fullNameController,
                                textInputAction: TextInputAction.next,
                                errorText: _validationErrors?['fullName'],
                                onChanged: (_) => setState(() {}),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Vui lòng nhập họ và tên'
                                        : null,
                              ),
                              AppTextField(
                                label: 'Số điện thoại',
                                hint: 'Ví dụ: 0912345678',
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                errorText: _validationErrors?['phone'],
                              ),
                              AppTextField(
                                label: 'Địa chỉ',
                                hint: 'Ví dụ: TP. Hồ Chí Minh, Việt Nam',
                                controller: _addressController,
                                textInputAction: TextInputAction.next,
                                errorText: _validationErrors?['address'],
                              ),
                              AppTextField(
                                label: 'Định danh công khai (@handle)',
                                hint: 'Ví dụ: minhdanh.travel',
                                controller: _handleController,
                                textInputAction: TextInputAction.next,
                                errorText: _validationErrors?['handle'],
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập định danh handle';
                                  }
                                  var trimmed = value.trim().toLowerCase();
                                  if (trimmed.startsWith('@')) {
                                    trimmed = trimmed.substring(1).trim();
                                  }
                                  if (trimmed.length < 3 || trimmed.length > 30) {
                                    return 'Handle phải từ 3 đến 30 ký tự';
                                  }
                                  if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(trimmed)) {
                                    return 'Chỉ chấp nhận chữ thường, số, dấu chấm và gạch dưới';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            twoCols: isWide,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Ảnh đại diện (URL)',
                                  hint: 'https://example.com/avatar.jpg',
                                  controller: _avatarController,
                                  focusNode: _avatarFocusNode,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.next,
                                  errorText: _validationErrors?['avatar'],
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Tooltip(
                                  message: 'Xem trước ảnh đại diện',
                                  child: _buildAvatarWidget(
                                    _avatarController.text,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Giới thiệu',
                            hint: 'Chia sẻ ngắn về sở thích du lịch của bạn...',
                            controller: _bioController,
                            keyboardType: TextInputType.multiline,
                            maxLines: 3,
                            minLines: 2,
                            textInputAction: TextInputAction.newline,
                            errorText: _validationErrors?['bio'],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _portalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _cardSectionTitle(
                            Icons.lock_outline,
                            'Thông tin tài khoản',
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Các trường hệ thống được bảo vệ và không thể thay đổi tại đây',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildResponsiveTwoColFields(
                            [
                              AppTextField(
                                label: 'Email',
                                controller: _emailController,
                                readOnly: true,
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                suffixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              AppTextField(
                                label: 'Vai trò',
                                controller: _roleController,
                                readOnly: true,
                                prefixIcon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                suffixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            twoCols: isWide,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _portalCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            onPressed: _saving
                                ? null
                                : () {
                                    _fillFields(_profile!);
                                    setState(() {
                                      _validationErrors = null;
                                      _editing = false;
                                    });
                                  },
                            child: const Text('Hủy bỏ'),
                          ),
                          ElevatedButton.icon(
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF43F5E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            onPressed: _saving ? null : _saveProfile,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 35,
                          child: _buildSummaryCard(isEditMode: true),
                        ),
                        const SizedBox(width: 24),
                        Expanded(flex: 65, child: formColumn),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(isEditMode: true),
                    const SizedBox(height: 20),
                    formColumn,
                  ],
                );
              },
            ),
          ),
        );
      }
}
