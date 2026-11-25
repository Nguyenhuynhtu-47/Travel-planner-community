import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Standard enterprise text input field for Admin screens.
/// Features stacked labels, 4px micro-radius, and clear focus/error states.
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? fillColor;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final TextStyle? labelStyle;
  final TextStyle? inputStyle;
  final TextStyle? hintStyle;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.fillColor,
    this.focusNode,
    this.validator,
    this.labelStyle,
    this.inputStyle,
    this.hintStyle,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMaxLines = widget.isPassword ? 1 : widget.maxLines;
    // Flutter asserts if TextInputAction.newline is paired with maxLines > 1
    // and TextInputType.text; automatically upgrade to multiline.
    final effectiveKeyboardType = (!widget.isPassword &&
            effectiveMaxLines > 1 &&
            widget.keyboardType == TextInputType.text)
        ? TextInputType.multiline
        : widget.keyboardType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: widget.labelStyle ??
              AppTypography.labelControl.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: effectiveKeyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword ? _obscureText : false,
          maxLines: effectiveMaxLines,
          minLines: widget.isPassword ? 1 : widget.minLines,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: widget.inputStyle ??
              AppTypography.bodyData.copyWith(
                color: widget.readOnly || !widget.enabled
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: widget.hintStyle,
            errorText: widget.errorText,
            filled: widget.fillColor != null || widget.readOnly || !widget.enabled,
            fillColor: widget.fillColor ??
                ((widget.readOnly || !widget.enabled)
                    ? const Color(0xFFF8FAFC)
                    : null),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      key: ValueKey(_obscureText),
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}
