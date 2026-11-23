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
  final String? Function(String?)? validator;

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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: AppTypography.labelControl.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword ? _obscureText : false,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.isPassword ? 1 : widget.minLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: AppTypography.bodyData.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
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
                : null,
          ),
        ),
      ],
    );
  }
}
