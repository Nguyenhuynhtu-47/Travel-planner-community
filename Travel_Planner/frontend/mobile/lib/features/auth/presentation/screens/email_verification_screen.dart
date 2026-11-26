import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_otp_input.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import '../widgets/auth_wave_header.dart';

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
      AppToast.showSuccess(
        context,
        'Kích hoạt tài khoản thành công! Đang đăng nhập...',
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else if (mounted) {
      final error = widget.authNotifier.errorMessage;
      if (error != null) {
        AppToast.showError(context, error);
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
        AppToast.showInfo(
          context,
          message ?? 'Đã gửi lại mã xác thực mới vào email.',
        );
        _startCountdown();
      }
    } catch (_) {
      if (mounted) {
        final error = widget.authNotifier.errorMessage ?? 'Không thể gửi lại mã xác thực lúc này.';
        AppToast.showError(context, error);
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

        return AuthScreenScaffold(
          headerIcon: Icons.mark_email_unread_outlined,
          showBackButton: true,
          title: 'Xác thực tài khoản',
          subtitleWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AuthUiTokens.subtitle,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: 'Mã xác thực gồm 6 chữ số đã được gửi tới email:\n',
                ),
                TextSpan(
                  text: widget.email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AuthUiTokens.title,
                  ),
                ),
              ],
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error Banner if present
                if (errorMessage != null) ...[
                  AuthErrorBanner(message: errorMessage),
                  const SizedBox(height: 20),
                ],

                // 6-box OTP input component
                AppOtpInput(
                  controller: _codeController,
                  enabled: !isLoading,
                  activeBorderColor: AuthUiTokens.primary,
                  onChanged: (code) {
                    setState(() {});
                  },
                  onCompleted: (code) {
                    _submitVerification();
                  },
                ),
                const SizedBox(height: 28),

                AuthPrimaryButton(
                  text: 'Kích hoạt tài khoản',
                  isLoading: isLoading,
                  onPressed: (_codeController.text.trim().length == 6 && !isLoading)
                      ? _submitVerification
                      : null,
                ),
                const SizedBox(height: 20),

                // Resend OTP Action
                Center(
                  child: _secondsRemaining > 0
                      ? Text(
                          'Gửi lại mã sau $_secondsRemaining giây',
                          style: const TextStyle(
                            color: AuthUiTokens.subtitle,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AuthUiTokens.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  size: 18,
                                  color: AuthUiTokens.primary,
                                ),
                          label: const Text(
                            'Gửi lại mã xác thực',
                            style: TextStyle(
                              color: AuthUiTokens.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
