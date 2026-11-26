import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final String email;
  final String? resetToken;
  final String? otp;

  const ResetPasswordScreen({
    super.key,
    required this.authNotifier,
    required this.email,
    this.resetToken,
    this.otp,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitResetPassword() async {
    widget.authNotifier.clearErrors();
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.authNotifier.resetPassword(
        email: widget.email,
        resetToken: widget.resetToken,
        otp: widget.otp,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;

      final message = response['message'] as String? ??
          'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
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
          _errorMessage = 'Không thể đặt lại mật khẩu. Vui lòng thử lại sau.';
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
    return AuthScreenScaffold(
      headerIcon: Icons.lock_outline_rounded,
      showBackButton: true,
      onBack: () {
        // Cancel reset and return to Login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/login'),
            builder: (_) => LoginScreen(authNotifier: widget.authNotifier),
          ),
          (route) => route.isFirst,
        );
      },
      title: 'Đặt lại mật khẩu',
      subtitle: 'Thiết lập mật khẩu mới cho tài khoản của bạn.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // New Password field (Relaxed password policy: min 6 chars, no complex char requirements)
            AuthTextField(
              label: 'Mật khẩu mới',
              hint: 'Tối thiểu 6 ký tự',
              controller: _newPasswordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu mới';
                }
                if (value.length < 6) {
                  return 'Mật khẩu phải có tối thiểu 6 ký tự';
                }
                if (value.length > 100) {
                  return 'Mật khẩu tối đa 100 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password field
            AuthTextField(
              label: 'Xác nhận mật khẩu mới',
              hint: 'Nhập lại mật khẩu mới',
              controller: _confirmPasswordController,
              prefixIcon: Icons.lock_reset_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitResetPassword(),
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
              const SizedBox(height: 16),
              AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 28),
            AuthPrimaryButton(
              text: 'Đặt lại mật khẩu',
              isLoading: _isLoading,
              onPressed: _submitResetPassword,
            ),
          ],
        ),
      ),
    );
  }
}
