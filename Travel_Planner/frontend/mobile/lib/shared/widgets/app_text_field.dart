import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

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
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? labelStyle;
  final TextStyle? inputStyle;
  final TextStyle? hintStyle;
  final IconData? prefixIcon;
  final double? borderRadius;
  final Color? focusedBorderColor;

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
    this.validator,
    this.inputFormatters,
    this.labelStyle,
    this.inputStyle,
    this.hintStyle,
    this.prefixIcon,
    this.borderRadius,
    this.focusedBorderColor,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: widget.labelStyle ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          obscureText: widget.isPassword ? _obscureText : false,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.isPassword ? 1 : widget.minLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: widget.inputStyle ??
              const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: widget.hintStyle,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: AppColors.textSecondary,
                    size: 20,
                  )
                : null,
            border: widget.borderRadius != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius!),
                    borderSide: const BorderSide(color: AppColors.border),
                  )
                : null,
            enabledBorder: widget.borderRadius != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius!),
                    borderSide: const BorderSide(color: AppColors.border),
                  )
                : null,
            focusedBorder: (widget.borderRadius != null || widget.focusedBorderColor != null)
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
                    borderSide: BorderSide(
                      color: widget.focusedBorderColor ?? AppColors.textPrimary,
                      width: 2.0,
                    ),
                  )
                : null,
            errorBorder: widget.borderRadius != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius!),
                    borderSide: const BorderSide(color: AppColors.error),
                  )
                : null,
            focusedErrorBorder: widget.borderRadius != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius!),
                    borderSide: const BorderSide(color: AppColors.error, width: 2.0),
                  )
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: AnimatedSwitcher(
                      duration:
                          MediaQuery.maybeOf(context)?.disableAnimations ??
                              false
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        key: ValueKey(_obscureText),
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
