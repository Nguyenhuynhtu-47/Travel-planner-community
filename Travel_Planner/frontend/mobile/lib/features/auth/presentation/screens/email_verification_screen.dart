import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_otp_input.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../auth_notifier.dart';

class EmailVerificationScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.authNotifier,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
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

  Future<void> _submitVerification() async {
    widget.authNotifier.clearErrors();
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    if (code.length != 6) return;

    final success = await widget.authNotifier.verifyEmail(
      email: widget.email,
      code: code,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kích hoạt tài khoản thành công! Đang đăng nhập...',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() => _isResending = true);
    widget.authNotifier.clearErrors();

    try {
      final message = await widget.authNotifier.resendVerification(
        email: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Đã gửi lại mã xác thực mới vào email.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        _startCountdown();
      }
    } catch (_) {
      if (mounted) {
        final error = widget.authNotifier.errorMessage ?? 'Không thể gửi lại mã xác thực lúc này.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authNotifier,
      builder: (context, _) {
        final isLoading = widget.authNotifier.isLoading;
        final errorMessage = widget.authNotifier.errorMessage;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                            Icons.mark_email_unread_outlined,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Xác thực tài khoản',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(text: 'Mã xác thực gồm 6 chữ số đã được gửi tới email:\n'),
                              TextSpan(
                                text: widget.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner if present
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 6-box OTP input component
                        AppOtpInput(
                          controller: _codeController,
                          enabled: !isLoading,
                          onChanged: (code) {
                            setState(() {});
                          },
                          onCompleted: (code) {
                            _submitVerification();
                          },
                        ),
                        const SizedBox(height: 28),

                        AppPrimaryButton(
                          text: 'Kích hoạt tài khoản',
                          isLoading: isLoading,
                          onPressed: (_codeController.text.trim().length == 6 && !isLoading)
                              ? _submitVerification
                              : null,
                        ),
                        const SizedBox(height: 24),

                        // Resend OTP Action
                        Center(
                          child: _secondsRemaining > 0
                              ? Text(
                                  'Gửi lại mã sau $_secondsRemaining giây',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: _isResending ? null : _resendCode,
                                  icon: _isResending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.refresh, size: 18),
                                  label: const Text(
                                    'Gửi lại mã xác thực',
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
