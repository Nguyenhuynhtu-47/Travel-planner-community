import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import '../widgets/auth_wave_header.dart';
import 'forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    required this.authNotifier,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForgotPassword() async {
    widget.authNotifier.clearErrors();
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.authNotifier.forgotPassword(email);
      if (!mounted) return;

      final message = response['message'] as String? ??
          'Nếu địa chỉ email tồn tại trong hệ thống, mã xác nhận đặt lại mật khẩu sẽ được gửi đến hộp thư của bạn.';
      final cooldown = (response['cooldownSeconds'] as num?)?.toInt() ?? 60;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );

      // Navigate to Step 2 — ForgotPasswordOtpScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/forgot-password-otp'),
          builder: (_) => ForgotPasswordOtpScreen(
            authNotifier: widget.authNotifier,
            email: email,
            initialCooldown: cooldown,
          ),
        ),
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
          _errorMessage = 'Không thể gửi yêu cầu đặt lại mật khẩu. Vui lòng thử lại sau.';
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
      headerIcon: Icons.lock_reset,
      showBackButton: true,
      title: 'Quên mật khẩu?',
      subtitle: 'Nhập email tài khoản của bạn để nhận mã OTP gồm 6 chữ số đặt lại mật khẩu.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthTextField(
              label: 'Địa chỉ Email',
              hint: 'example@domain.com',
              controller: _emailController,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitForgotPassword(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập email';
                }
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Định dạng email không hợp lệ';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 28),
            AuthPrimaryButton(
              text: 'Tiếp tục',
              isLoading: _isLoading,
              onPressed: _submitForgotPassword,
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Quay lại Đăng nhập',
                  style: TextStyle(
                    color: AuthUiTokens.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
