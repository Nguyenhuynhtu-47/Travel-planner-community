import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_otp_input.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../auth_notifier.dart';
import '../widgets/auth_screen_scaffold.dart';
import '../widgets/auth_wave_header.dart';
import 'reset_password_screen.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final String email;
  final int initialCooldown;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.authNotifier,
    required this.email,
    this.initialCooldown = 60,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final _codeController = TextEditingController();
  Timer? _countdownTimer;
  late int _secondsRemaining;
  bool _isResending = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialCooldown > 0 ? widget.initialCooldown : 60;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown([int? seconds]) {
    if (seconds != null) {
      _secondsRemaining = seconds;
    }
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

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _isLoading) return;

    widget.authNotifier.clearErrors();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.authNotifier.verifyResetOtp(
        email: widget.email,
        otp: code,
      );

      if (!mounted) return;

      final resetToken = response['resetToken'] as String?;
      if (resetToken == null || resetToken.isEmpty) {
        throw ApiException(
          statusCode: 500,
          message: 'Không nhận được mã xác nhận hợp lệ từ máy chủ.',
        );
      }

      // Navigate to Step 3 using pushReplacement so user cannot return to the OTP step
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/reset-password'),
          builder: (_) => ResetPasswordScreen(
            authNotifier: widget.authNotifier,
            email: widget.email,
            resetToken: resetToken,
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
          _errorMessage = 'Không thể xác thực mã OTP. Vui lòng thử lại sau.';
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

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.authNotifier.forgotPassword(widget.email);
      if (!mounted) return;

      final cooldown = (response['cooldownSeconds'] as num?)?.toInt() ?? 60;
      _startCountdown(cooldown);

      AppToast.showSuccess(
        context,
        'Mã xác nhận mới đã được gửi nếu email tồn tại.',
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
          _errorMessage = 'Không thể gửi lại mã OTP. Vui lòng thử lại sau.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _codeController.text.trim().length == 6 && !_isLoading;

    return AuthScreenScaffold(
      headerIcon: Icons.lock_reset,
      showBackButton: true,
      title: 'Xác thực mã OTP',
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
              text: 'Mã xác thực gồm 6 chữ số đã được gửi tới email để đặt lại mật khẩu:\n',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error banner if any
          if (_errorMessage != null) ...[
            AuthErrorBanner(message: _errorMessage!),
            const SizedBox(height: 20),
          ],

          // 6-box OTP input
          AppOtpInput(
            controller: _codeController,
            enabled: !_isLoading,
            activeBorderColor: AuthUiTokens.primary,
            onChanged: (code) {
              setState(() {});
            },
            onCompleted: (code) {
              _verifyOtp();
            },
          ),
          const SizedBox(height: 28),

          // Verify button
          AuthPrimaryButton(
            text: 'Xác nhận mã OTP',
            isLoading: _isLoading,
            onPressed: canSubmit ? _verifyOtp : null,
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
                    onPressed: _isResending ? null : _resendOtp,
                    icon: _isResending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuthUiTokens.primary,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18, color: AuthUiTokens.primary),
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
          const SizedBox(height: 8),

          // Back to Step 1 link
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Chỉnh sửa địa chỉ email',
                style: TextStyle(
                  color: AuthUiTokens.subtitle,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
