import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import '../widgets/auth_wave_header.dart';
import '../widgets/google_sign_in_button.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập tên đăng nhập';
    }
    if (value.trim().isEmpty) {
      return 'Vui lòng nhập tên đăng nhập';
    }
    if (value.contains(' ')) {
      return 'Tên đăng nhập không được chứa khoảng trắng';
    }
    if (value.length < 3 || value.length > 50) {
      return 'Tên đăng nhập phải từ 3 đến 50 ký tự';
    }
    final regex = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!regex.hasMatch(value)) {
      return 'Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm';
    }
    return null;
  }

  const RegisterScreen({super.key, required this.authNotifier});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.authNotifier.clearErrors();
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      AppToast.showError(context, 'Mật khẩu xác nhận không khớp');
      return;
    }

    final success = await widget.authNotifier.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
    );

    if (success && mounted) {
      AppToast.showSuccess(
        context,
        'Đăng ký thành công! Vui lòng kiểm tra email để lấy mã xác thực.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            authNotifier: widget.authNotifier,
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else if (mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null) {
        AppToast.showError(context, error);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    widget.authNotifier.clearErrors();
    final success = await widget.authNotifier.loginWithGoogle();

    if (success && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else if (!success && mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null && error.isNotEmpty) {
        final isConflict = error.contains('liên kết') || error.contains('đã được sử dụng');
        if (isConflict) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Tài khoản đã tồn tại'),
              content: Text(error),
              actions: [
                BounceTap(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đã hiểu'),
                  ),
                ),
              ],
            ),
          );
        } else {
          AppToast.showError(
            context,
            error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authNotifier,
      builder: (context, _) {
        final valErrors = widget.authNotifier.validationErrors;

        return AuthScreenScaffold(
          isCompactHeader: true,
          compactTitle: 'Đăng ký tài khoản',
          compactSubtitle: 'Tạo tài khoản mới',
          showBackButton: true,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gia nhập cộng đồng chia sẻ lịch trình du lịch',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AuthUiTokens.subtitle,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                AuthTextField(
                  label: 'Tên đăng nhập',
                  hint: 'Ví dụ: hoanganh_travel',
                  controller: _usernameController,
                  prefixIcon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                  errorText: valErrors?['username'],
                  validator: RegisterScreen.validateUsername,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Họ và tên',
                  hint: 'Ví dụ: Nguyễn Hoàng Anh',
                  controller: _fullNameController,
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.next,
                  errorText: valErrors?['fullName'],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ và tên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Email',
                  hint: 'Ví dụ: hoanganh@example.com',
                  controller: _emailController,
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  errorText: valErrors?['email'],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Mật khẩu',
                  hint: 'Tối thiểu 6 ký tự',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  errorText: valErrors?['password'],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu phải có tối thiểu 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Xác nhận mật khẩu',
                  hint: 'Nhập lại mật khẩu',
                  controller: _confirmPasswordController,
                  prefixIcon: Icons.lock_reset_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng xác nhận mật khẩu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  text: 'Đăng ký',
                  isLoading: widget.authNotifier.isLoading,
                  onPressed: _submit,
                ),
                const AuthDividerWithText(text: 'Hoặc'),
                GoogleSignInButton(
                  text: 'Đăng ký bằng Google',
                  isLoading: widget.authNotifier.isLoading,
                  onPressed: _signInWithGoogle,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(
                        color: AuthUiTokens.subtitle,
                        fontSize: 14,
                      ),
                    ),
                    BounceTap(
                      child: GestureDetector(
                        onTap: () {
                          widget.authNotifier.clearErrors();
                          Navigator.pop(context);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Đăng nhập ngay',
                            style: TextStyle(
                              color: AuthUiTokens.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
