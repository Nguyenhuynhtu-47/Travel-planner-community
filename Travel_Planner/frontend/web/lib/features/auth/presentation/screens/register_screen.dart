import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../auth_notifier.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mật khẩu xác nhận không khớp',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await widget.authNotifier.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
    );

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
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
          appBar: AppBar(title: const Text('Đăng ký tài khoản')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tạo tài khoản mới',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Điền thông tin để đăng ký tài khoản Travel Planner',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppTextField(
                          label: 'Tên đăng nhập',
                          hint: 'Ví dụ: hoanganh_travel',
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          errorText: valErrors?['username'],
                          validator: RegisterScreen.validateUsername,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Họ và tên',
                          hint: 'Ví dụ: Nguyễn Hoàng Anh',
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          errorText: valErrors?['fullName'],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập họ và tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Email',
                          hint: 'Ví dụ: hoanganh@example.com',
                          controller: _emailController,
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
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Mật khẩu',
                          hint: 'Tối thiểu 6 ký tự',
                          controller: _passwordController,
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
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Xác nhận mật khẩu',
                          hint: 'Nhập lại mật khẩu',
                          controller: _confirmPasswordController,
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
                        const SizedBox(height: 28),
                        AppPrimaryButton(
                          text: 'Đăng ký',
                          isLoading: widget.authNotifier.isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Đã có tài khoản? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  widget.authNotifier.clearErrors();
                                  Navigator.pop(context);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'Đăng nhập ngay',
                                    style: TextStyle(
                                      color: AppColors.primary,
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
