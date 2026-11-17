import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/services/image_picker_service.dart';
import '../../../../shared/widgets/image_upload_preview.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';
import '../../data/profile_repository.dart';

class PersonalInfoScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ProfileRepository? repository;
  final ImagePickerService? imagePickerService;

  const PersonalInfoScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.imagePickerService,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  late final ProfileRepository _repository;
  late final ImagePickerService _imagePickerService;

  Map<String, dynamic>? _profile;
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ProfileRepository();
    _imagePickerService =
        widget.imagePickerService ?? DeviceImagePickerService();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _handleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillFields(Map<String, dynamic> p) {
    _fullNameController.text = p['fullName']?.toString() ?? '';
    _handleController.text = p['handle']?.toString() ?? '';
    _selectedAvatar = null;
    _selectedAvatarBytes = null;
    _phoneController.text = p['phone']?.toString() ?? '';
    _addressController.text = p['address']?.toString() ?? '';
    _bioController.text = p['bio']?.toString() ?? '';
  }

  Future<void> _loadProfile() async {
    final token = widget.authNotifier.token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _profile = null;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _repository.getProfile(token);
      if (mounted) {
        setState(() {
          _profile = profile;
          _fillFields(profile);
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

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePickerService.pickImage();
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ảnh không được vượt quá 5 MB')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _selectedAvatar = image;
          _selectedAvatarBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở thư viện ảnh. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final token = widget.authNotifier.token;
    if (token == null) return;

    setState(() {
      _saving = true;
    });

    try {
      String? avatarUrl = _profile?['avatar']?.toString();
      final selectedAvatar = _selectedAvatar;
      final selectedBytes = _selectedAvatarBytes;
      if (selectedAvatar != null && selectedBytes != null) {
        avatarUrl = await _repository.uploadImage(
          token,
          bytes: selectedBytes,
          filename: selectedAvatar.name,
        );
      }
      final rawHandle = _handleController.text.trim().toLowerCase();
      final cleanHandle = rawHandle.startsWith('@')
          ? rawHandle.substring(1).trim()
          : rawHandle;
      final profile = await _repository.updateProfile(token, {
        'fullName': _fullNameController.text.trim(),
        'handle': cleanHandle,
        'avatar': avatarUrl ?? '',
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      await widget.authNotifier.updateCurrentUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fillFields(profile);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hồ sơ'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu thông tin hồ sơ. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.authNotifier.logout();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Thông tin cá nhân'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, size: 22, color: AppColors.error),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: AppColors.hairlineSoft,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadProfile,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final p = _profile ?? {};
    final currentAvatar = p['avatar']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar editing
            Center(
              child: ImageUploadPreview(
                selectedBytes: _selectedAvatarBytes,
                imageUrl: currentAvatar,
                buttonLabel: 'Đổi ảnh đại diện',
                onPick: _pickAvatar,
              ),
            ),
            const SizedBox(height: 24),

            _sectionHeader('Thông tin cơ bản'),
            const SizedBox(height: 12),

            AppTextField(
              label: 'Họ và tên *',
              hint: 'Nhập họ và tên của bạn',
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Họ và tên không được để trống';
                }
                if (v.trim().length > 100) {
                  return 'Họ và tên tối đa 100 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Định danh công khai (@handle)',
              hint: 'ví dụ: minhdanh (chữ thường, số, dấu chấm)',
              controller: _handleController,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                var handle = v.trim().toLowerCase();
                if (handle.startsWith('@')) handle = handle.substring(1).trim();
                if (handle.length < 3 || handle.length > 30) {
                  return 'Handle phải từ 3 đến 30 ký tự';
                }
                if (!RegExp(r'^[a-z0-9._]+$').hasMatch(handle)) {
                  return 'Chỉ chấp nhận chữ thường, số, dấu chấm và gạch dưới';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Số điện thoại',
              hint: 'Nhập số điện thoại',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Địa chỉ',
              hint: 'Tỉnh/Thành phố hoặc địa chỉ của bạn',
              controller: _addressController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'Giới thiệu',
              hint: 'Mô tả ngắn gọn về bản thân hoặc sở thích du lịch...',
              controller: _bioController,
              maxLines: 3,
              minLines: 2,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),

            _sectionHeader('Thông tin tài khoản'),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _readonlyRow('Email', p['email']),
                  const Divider(height: 1, color: AppColors.hairlineSoft),
                  _readonlyRow('Vai trò', _value(p['role'])),
                  const Divider(height: 1, color: AppColors.hairlineSoft),
                  _readonlyRow('Trạng thái', _value(p['status'])),
                  const Divider(height: 1, color: AppColors.hairlineSoft),
                  _readonlyRow('Ngày tham gia', _formatDate(p['createdAt']) ?? 'Chưa rõ'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionHeader('Bảo mật tài khoản'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangePasswordScreen(
                      authNotifier: widget.authNotifier,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.lock_reset, size: 20),
              label: const Text('Đổi mật khẩu'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 32),

            AppPrimaryButton(
              text: 'Lưu thay đổi',
              isLoading: _saving,
              onPressed: _saveProfile,
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
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _readonlyRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value?.toString() ?? 'Chưa cập nhật',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
