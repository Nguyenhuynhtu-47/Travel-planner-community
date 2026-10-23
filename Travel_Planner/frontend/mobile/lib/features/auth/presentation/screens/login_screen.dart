import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../auth_notifier.dart';
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

    if (!success && mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authNotifier,
      builder: (context, _) {
        final valErrors = widget.authNotifier.validationErrors;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(
                          child: Icon(
                            Icons.travel_explore,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Travel Planner',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng nhập để tiếp tục kế hoạch du lịch của bạn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AppTextField(
                          label: 'Tên đăng nhập hoặc Email',
                          hint: 'Nhập tên đăng nhập hoặc email',
                          controller: _usernameOrEmailController,
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
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu',
                          controller: _passwordController,
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
                        const SizedBox(height: 28),
                        AppPrimaryButton(
                          text: 'Đăng nhập',
                          isLoading: widget.authNotifier.isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Chưa có tài khoản? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
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
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
