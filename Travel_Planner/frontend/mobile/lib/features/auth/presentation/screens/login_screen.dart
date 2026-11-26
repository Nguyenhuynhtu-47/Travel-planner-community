import 'package:flutter/material.dart';

import '../../../../shared/navigation/main_navigation_shell.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import '../widgets/auth_wave_header.dart';
import '../widgets/google_sign_in_button.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const LoginScreen({super.key, required this.authNotifier});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.authNotifier.clearErrors();
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.authNotifier.login(
      _usernameOrEmailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                MainNavigationShell(authNotifier: widget.authNotifier),
          ),
        );
      }
    } else if (!success && mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null) {
        final isUnverified = error.contains('chưa được kích hoạt');
        AppToast.showError(
          context,
          error,
          duration: Duration(seconds: isUnverified ? 8 : 4),
          actionLabel: isUnverified ? 'Kích hoạt ngay' : null,
          onAction: isUnverified
              ? () {
                  final input = _usernameOrEmailController.text.trim();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailVerificationScreen(
                        authNotifier: widget.authNotifier,
                        email: input.contains('@') ? input : '',
                      ),
                    ),
                  );
                }
              : null,
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    widget.authNotifier.clearErrors();
    final success = await widget.authNotifier.loginWithGoogle();

    if (success && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                MainNavigationShell(authNotifier: widget.authNotifier),
          ),
        );
      }
    } else if (!success && mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null && error.isNotEmpty) {
        final isConflict =
            error.contains('liên kết') || error.contains('đã được sử dụng');
        if (isConflict) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Tài khoản đã tồn tại'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
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
          headerIcon: Icons.travel_explore,
          waveHeightRatio: 0.19,
          badgeSize: 64,
          showBackButton: false,
          scrollOnlyWithKeyboard: true,
          bodyPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          headerToFormSpacing: 16,
          title: 'Travel Planner',
          subtitle: 'Đăng nhập để tiếp tục kế hoạch du lịch của bạn',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthTextField(
                  label: 'Tên đăng nhập hoặc Email',
                  hint: 'Nhập tên đăng nhập hoặc email',
                  controller: _usernameOrEmailController,
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  errorText: valErrors?['usernameOrEmail'],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên đăng nhập hoặc email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  label: 'Mật khẩu',
                  hint: 'Nhập mật khẩu',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  errorText: valErrors?['password'],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      widget.authNotifier.clearErrors();
                      final input = _usernameOrEmailController.text.trim();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            authNotifier: widget.authNotifier,
                            initialEmail: input.contains('@') ? input : null,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        color: AuthUiTokens.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AuthPrimaryButton(
                  text: 'Đăng nhập',
                  isLoading: widget.authNotifier.isLoading,
                  onPressed: _submit,
                ),
                const AuthDividerWithText(text: 'Hoặc', verticalPadding: 12),
                GoogleSignInButton(
                  text: 'Đăng nhập bằng Google',
                  isLoading: widget.authNotifier.isLoading,
                  onPressed: _signInWithGoogle,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(
                        color: AuthUiTokens.subtitle,
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        widget.authNotifier.clearErrors();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(
                              authNotifier: widget.authNotifier,
                            ),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            color: AuthUiTokens.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
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
