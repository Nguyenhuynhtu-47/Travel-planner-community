import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import 'auth_wave_header.dart';

/// Shared scaffold for all Authentication Flow screens.
///
/// Combines the full-bleed [AuthWaveHeader] with a keyboard-safe scrollable
/// white body, consistent horizontal constraints, and optional standard header
/// title/subtitle below the floating icon badge.
class AuthScreenScaffold extends StatelessWidget {
  final IconData? headerIcon;
  final bool isCompactHeader;
  final double? waveHeightRatio;
  final double? badgeSize;
  final String? compactTitle;
  final String? compactSubtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String? title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final EdgeInsetsGeometry? bodyPadding;
  final double? headerToFormSpacing;
  final bool scrollOnlyWithKeyboard;
  final Widget child;

  const AuthScreenScaffold({
    super.key,
    this.headerIcon,
    this.isCompactHeader = false,
    this.waveHeightRatio,
    this.badgeSize,
    this.compactTitle,
    this.compactSubtitle,
    this.showBackButton = true,
    this.onBack,
    this.title,
    this.subtitle,
    this.subtitleWidget,
    this.bodyPadding,
    this.headerToFormSpacing,
    this.scrollOnlyWithKeyboard = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final ScrollPhysics scrollPhysics = (scrollOnlyWithKeyboard && !isKeyboardOpen)
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();

    return Scaffold(
      backgroundColor: AuthUiTokens.background,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        physics: scrollPhysics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthWaveHeader(
              icon: headerIcon,
              isCompact: isCompactHeader,
              waveHeightRatio: waveHeightRatio,
              badgeSize: badgeSize,
              compactTitle: compactTitle,
              compactSubtitle: compactSubtitle,
              showBackButton: showBackButton,
              onBack: onBack,
            ),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: bodyPadding ??
                        EdgeInsets.fromLTRB(
                          24,
                          isCompactHeader ? 12 : 16,
                          24,
                          28,
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null) ...[
                          Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AuthUiTokens.title,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (subtitleWidget != null) ...[
                          subtitleWidget!,
                          SizedBox(height: headerToFormSpacing ?? 24),
                        ] else if (subtitle != null) ...[
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                              color: AuthUiTokens.subtitle,
                              height: 1.45,
                            ),
                          ),
                          SizedBox(height: headerToFormSpacing ?? 24),
                        ],
                        child,
                      ],
                    ),
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

/// Standardized Auth text field preset with 12px radius, #FA3E62 focus border,
/// and leading prefix icon.
class AuthTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.errorText,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      keyboardType: keyboardType,
      isPassword: isPassword,
      errorText: errorText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      prefixIcon: prefixIcon,
      borderRadius: 12,
      focusedBorderColor: AuthUiTokens.primary,
      labelStyle: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: AuthUiTokens.title,
      ),
      inputStyle: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w400,
        color: AuthUiTokens.title,
      ),
      hintStyle: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        color: AuthUiTokens.subtitle.withValues(alpha: 0.72),
      ),
    );
  }
}

/// Standardized Auth primary button preset (#FA3E62, #FAD2DA disabled, 50px height, 13px radius).
class AuthPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: AuthUiTokens.primary,
      disabledBackgroundColor: AuthUiTokens.primaryDisabled,
      borderRadius: 13,
      height: 50,
    );
  }
}

/// Consistent inline error banner for Auth screens.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
