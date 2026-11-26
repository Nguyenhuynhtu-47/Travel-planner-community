import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import '../widgets/auth_wave_header.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const ChangePasswordScreen({
    super.key,
    required this.authNotifier,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    widget.authNotifier.clearErrors();
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (currentPassword == newPassword) {
      setState(() {
        _errorMessage = 'Mật khẩu mới không được trùng với mật khẩu hiện tại.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.authNotifier.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;

      final message = response['message'] as String? ??
          'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.';

      AppToast.showSuccess(
        context,
        message,
        duration: const Duration(seconds: 4),
      );

      // Navigate cleanly back to Login screen (never Home)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/login'),
          builder: (_) => LoginScreen(authNotifier: widget.authNotifier),
        ),
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Đã có lỗi xảy ra khi đổi mật khẩu. Vui lòng thử lại sau.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#^()_+\-=\[\]{};' "'"
        r':"\\|,.<>\/]).{8,100}$');

    return AuthScreenScaffold(
      isCompactHeader: true,
      compactTitle: 'Đổi mật khẩu',
      compactSubtitle: 'Tạo mật khẩu mới',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mật khẩu mới phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt. Sau khi đổi mật khẩu thành công, bạn sẽ cần đăng nhập lại trên tất cả thiết bị.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: AuthUiTokens.subtitle,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Mật khẩu hiện tại',
              hint: 'Nhập mật khẩu đang sử dụng',
              controller: _currentPasswordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu hiện tại';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            AuthTextField(
              label: 'Mật khẩu mới',
              hint: 'Nhập mật khẩu mới',
              controller: _newPasswordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu mới';
                }
                if (!passwordRegex.hasMatch(value)) {
                  return 'Mật khẩu tối thiểu 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            AuthTextField(
              label: 'Xác nhận mật khẩu mới',
              hint: 'Nhập lại mật khẩu mới',
              controller: _confirmPasswordController,
              prefixIcon: Icons.lock_reset_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitChangePassword(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng xác nhận mật khẩu mới';
                }
                if (value != _newPasswordController.text) {
                  return 'Mật khẩu xác nhận không khớp';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 18),
            AuthPrimaryButton(
              text: 'Cập nhật mật khẩu',
              isLoading: _isLoading,
              onPressed: _submitChangePassword,
            ),
          ],
        ),
      ),
    );
  }
}
