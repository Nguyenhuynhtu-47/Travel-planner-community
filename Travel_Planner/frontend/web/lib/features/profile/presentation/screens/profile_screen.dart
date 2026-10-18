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
        const SnackBar(content: Text('Đã cập nhật hồ sơ')),
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
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu hồ sơ. Vui lòng thử lại.'),
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
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? _errorView()
              : _editing
                  ? _editor()
                  : _profileView(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _loadProfile, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _profileView() {
    final profile = _profile!;
    final avatar = profile['avatar']?.toString() ?? '';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primaryLight.withAlpha(45),
                        backgroundImage: avatar.startsWith('http')
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar.startsWith('http')
                            ? null
                            : const Icon(
                                Icons.person,
                                size: 52,
                                color: AppColors.primaryDark,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _value(profile['fullName']),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _detail('Tên đăng nhập', profile['username']),
                    _detail('Email', profile['email']),
                    _detail('Số điện thoại', profile['phone']),
                    _detail('Địa chỉ', profile['address']),
                    _detail('Giới thiệu', profile['bio']),
                    _detail('Vai trò', profile['role']),
                    _detail('Trạng thái tài khoản', profile['status']),
                    _detail('Ngày tham gia', _formatDate(profile['createdAt'])),
                    const SizedBox(height: 12),
                    AppPrimaryButton(
                      text: 'Chỉnh sửa hồ sơ',
                      onPressed: () => setState(() => _editing = true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _value(value),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
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
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Chỉnh sửa hồ sơ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Họ và tên',
                controller: _fullNameController,
                errorText: _validationErrors?['fullName'],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập họ và tên'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Ảnh đại diện (URL)',
                controller: _avatarController,
                keyboardType: TextInputType.url,
                errorText: _validationErrors?['avatar'],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Số điện thoại',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                errorText: _validationErrors?['phone'],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Địa chỉ',
                controller: _addressController,
                errorText: _validationErrors?['address'],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Giới thiệu',
                controller: _bioController,
                errorText: _validationErrors?['bio'],
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                text: 'Lưu thay đổi',
                isLoading: _saving,
                onPressed: _saveProfile,
              ),
              TextButton(
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
      ),
    );
  }
}
