import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_otp_input.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../auth_notifier.dart';

class ChangeEmailScreen extends StatefulWidget {
  final AuthNotifier authNotifier;

  const ChangeEmailScreen({
    super.key,
    required this.authNotifier,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _otpController = TextEditingController();

  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _countdownTimer;
  int _secondsRemaining = 60;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _passwordController.dispose();
    _newEmailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _requestEmailChange() async {
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newEmail = _newEmailController.text.trim();
      final password = _passwordController.text;

      await widget.authNotifier.requestEmailChange(
        newEmail: newEmail,
        password: password.isNotEmpty ? password : null,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 2;
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể gửi yêu cầu đổi email. Vui lòng thử lại sau.';
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newEmail = _newEmailController.text.trim();
      final password = _passwordController.text;

      await widget.authNotifier.requestEmailChange(
        newEmail: newEmail,
        password: password.isNotEmpty ? password : null,
      );

      if (!mounted) return;
      _startCountdown();
      AppToast.showSuccess(
        context,
        'Mã xác thực mới đã được gửi đến email.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể gửi lại mã xác thực.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyEmailChange() async {
    if (!_step2FormKey.currentState!.validate()) return;
    if (_otpController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã xác thực.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newEmail = _newEmailController.text.trim();
      final otp = _otpController.text.trim();

      final res = await widget.authNotifier.verifyEmailChange(
        newEmail: newEmail,
        otp: otp,
      );

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        res['message']?.toString() ?? 'Đổi địa chỉ email thành công',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Xác thực đổi email thất bại. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Đổi địa chỉ email'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: AppColors.hairlineSoft,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nhập mật khẩu hiện tại và địa chỉ email mới. Hệ thống sẽ gửi mã xác thực 6 chữ số đến email mới để hoàn tất.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 13, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          AppTextField(
            label: 'Mật khẩu hiện tại *',
            hint: 'Nhập mật khẩu tài khoản',
            controller: _passwordController,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Vui lòng nhập mật khẩu hiện tại';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            label: 'Địa chỉ email mới *',
            hint: 'ví dụ: newemail@example.com',
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email mới không được để trống';
              }
              final email = v.trim();
              if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
                return 'Định dạng email không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          AppPrimaryButton(
            text: 'Tiếp tục',
            isLoading: _isLoading,
            onPressed: _requestEmailChange,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final newEmail = _newEmailController.text.trim();

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mã xác thực 6 chữ số đã được gửi đến địa chỉ:',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            newEmail,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 13, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          AppOtpInput(
            controller: _otpController,
            onChanged: (val) {
              if (val.length == 6) {
                _verifyEmailChange();
              }
            },
          ),
          const SizedBox(height: 24),

          Center(
            child: _secondsRemaining > 0
                ? Text(
                    'Gửi lại mã sau $_secondsRemaining giây',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  )
                : TextButton(
                    onPressed: _isLoading ? null : _resendOtp,
                    child: const Text(
                      'Gửi lại mã xác thực',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          AppPrimaryButton(
            text: 'Xác nhận đổi email',
            isLoading: _isLoading,
            onPressed: _verifyEmailChange,
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
                _errorMessage = null;
              });
            },
            child: const Text(
              'Thay đổi email khác',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
