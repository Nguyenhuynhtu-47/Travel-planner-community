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
  final _fullName = TextEditingController(), _avatar = TextEditingController();
  final _phone = TextEditingController(), _address = TextEditingController(), _bio = TextEditingController();
  final _repository = ProfileRepository();
  Map<String, dynamic>? _profile;
  bool _loading = true, _saving = false, _editing = false;
  String? _error;
  Map<String, String>? _validationErrors;

  Future<void> _logout() async {
    await widget.authNotifier.logout();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void initState() { super.initState(); _loadProfile(); }
  @override
  void dispose() {
    _fullName.dispose(); _avatar.dispose(); _phone.dispose(); _address.dispose(); _bio.dispose(); super.dispose();
  }

  void _fillFields(Map<String, dynamic> p) {
    _fullName.text = p['fullName']?.toString() ?? ''; _avatar.text = p['avatar']?.toString() ?? '';
    _phone.text = p['phone']?.toString() ?? ''; _address.text = p['address']?.toString() ?? '';
    _bio.text = p['bio']?.toString() ?? '';
  }

  Future<void> _loadProfile() async {
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _repository.getProfile(token);
      if (mounted) setState(() { _profile = profile; _fillFields(profile); _loading = false; });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _logout();
        return;
      }
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Không thể tải hồ sơ. Vui lòng thử lại.'; _loading = false; });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() { _saving = true; _validationErrors = null; });
    try {
      final profile = await _repository.updateProfile(token, {
        'fullName': _fullName.text.trim(), 'avatar': _avatar.text.trim(),
        'phone': _phone.text.trim(), 'address': _address.text.trim(), 'bio': _bio.text.trim(),
      });
      await widget.authNotifier.updateCurrentUser(profile);
      if (!mounted) return;
      setState(() { _profile = profile; _fillFields(profile); _editing = false; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ')));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() { _saving = false; _validationErrors = e.validationErrors; });
        if (e.statusCode == 401) {
          await _logout();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể lưu hồ sơ. Vui lòng thử lại.'), backgroundColor: AppColors.error));
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ cá nhân'), actions: [
      IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: _logout),
    ]),
    body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16), OutlinedButton(onPressed: _loadProfile, child: const Text('Thử lại')),
        ]))) : _editing ? _editor() : _profileView(),
  );

  Widget _profileView() {
    final p = _profile!; final avatar = p['avatar']?.toString() ?? '';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Center(child: CircleAvatar(radius: 44, backgroundColor: AppColors.primaryLight.withAlpha(45),
        backgroundImage: avatar.startsWith('http') ? NetworkImage(avatar) : null,
        child: avatar.startsWith('http') ? null : const Icon(Icons.person, size: 48, color: AppColors.primaryDark))),
      const SizedBox(height: 16), Center(child: Text(_value(p['fullName']), style: Theme.of(context).textTheme.headlineMedium)),
      const SizedBox(height: 28), _detail('Tên đăng nhập', p['username']), _detail('Email', p['email']),
      _detail('Số điện thoại', p['phone']), _detail('Địa chỉ', p['address']), _detail('Giới thiệu', p['bio']),
      _detail('Vai trò', p['role']), _detail('Trạng thái tài khoản', p['status']),
      _detail('Ngày tham gia', _formatDate(p['createdAt'])),
      const SizedBox(height: 24), AppPrimaryButton(text: 'Chỉnh sửa hồ sơ', onPressed: () => setState(() => _editing = true)),
    ]);
  }

  Widget _detail(String label, dynamic value) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)), const SizedBox(height: 4),
      Text(_value(value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
    ],
  ));

  String? _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _editor() => Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(24), children: [
    const Text('Thông tin cá nhân', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    const SizedBox(height: 20),
    AppTextField(label: 'Họ và tên', controller: _fullName, errorText: _validationErrors?['fullName'], validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null),
    const SizedBox(height: 16), AppTextField(label: 'Ảnh đại diện (URL)', controller: _avatar, keyboardType: TextInputType.url, errorText: _validationErrors?['avatar']),
    const SizedBox(height: 16), AppTextField(label: 'Số điện thoại', controller: _phone, keyboardType: TextInputType.phone, errorText: _validationErrors?['phone']),
    const SizedBox(height: 16), AppTextField(label: 'Địa chỉ', controller: _address, errorText: _validationErrors?['address']),
    const SizedBox(height: 16), AppTextField(label: 'Giới thiệu', controller: _bio, errorText: _validationErrors?['bio']),
    const SizedBox(height: 24), AppPrimaryButton(text: 'Lưu thay đổi', isLoading: _saving, onPressed: _saveProfile),
    TextButton(onPressed: _saving ? null : () { _fillFields(_profile!); setState(() => _editing = false); }, child: const Text('Hủy')),
  ]));
}
