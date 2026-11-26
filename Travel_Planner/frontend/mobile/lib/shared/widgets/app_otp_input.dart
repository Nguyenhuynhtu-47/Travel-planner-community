import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Reusable responsive 6-box OTP Input Widget
///
/// Provides 6 distinct digit boxes with auto-focus advance, backspace regression,
/// full 6-digit paste distribution, numeric keyboard, and active focus highlighting.
///
/// Guaranteed zero horizontal overflow via responsive Expanded/AspectRatio layout
/// and clean single-border styling with no duplicated or theme-inherited outlines.
class AppOtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autoFocus;
  final String? errorText;
  final TextEditingController? controller;
  final Color? activeBorderColor;

  const AppOtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.autoFocus = true,
    this.errorText,
    this.controller,
    this.activeBorderColor,
  });

  @override
  State<AppOtpInput> createState() => _AppOtpInputState();
}

class _AppOtpInputState extends State<AppOtpInput> {
  late final List<TextEditingController> _boxControllers;
  late final List<FocusNode> _focusNodes;
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    _boxControllers = List.generate(
      widget.length,
      (index) => TextEditingController(),
    );

    _focusNodes = List.generate(
      widget.length,
      (index) {
        final node = FocusNode(
          onKeyEvent: (node, event) => _handleKeyEvent(index, event),
        );
        node.addListener(() {
          if (node.hasFocus && mounted) {
            setState(() {
              _focusedIndex = index;
            });
          } else if (_focusedIndex == index && mounted) {
            setState(() {
              _focusedIndex = -1;
            });
          }
        });
        return node;
      },
    );

    // Sync from initial controller if provided
    if (widget.controller != null && widget.controller!.text.isNotEmpty) {
      _syncFromExternalText(widget.controller!.text);
    }

    widget.controller?.addListener(_onExternalControllerChanged);

    if (widget.autoFocus && widget.length > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) {
          _focusNodes[0].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onExternalControllerChanged);
    for (final c in _boxControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onExternalControllerChanged() {
    if (widget.controller == null) return;
    final currentCode = _currentCode;
    if (widget.controller!.text != currentCode) {
      _syncFromExternalText(widget.controller!.text);
    }
  }

  void _syncFromExternalText(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < widget.length; i++) {
      if (i < digits.length) {
        _boxControllers[i].text = digits[i];
      } else {
        _boxControllers[i].text = '';
      }
    }
  }

  String get _currentCode {
    return _boxControllers.map((c) => c.text).join();
  }

  void _notifyChanged() {
    final code = _currentCode;
    if (widget.controller != null && widget.controller!.text != code) {
      widget.controller!.text = code;
    }
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  void _onBoxChanged(int index, String value) {
    if (!widget.enabled) return;

    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Handle pasting multi-digit string into any box
    if (digits.length > 1) {
      _distributePastedDigits(index, digits);
      return;
    }

    if (digits.isNotEmpty) {
      // Single digit typed (take the last char if replacement occurred)
      final singleDigit = digits.substring(digits.length - 1);
      _boxControllers[index].text = singleDigit;
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      _boxControllers[index].text = '';
    }

    _notifyChanged();
  }

  void _distributePastedDigits(int startIndex, String digits) {
    // If full code pasted (e.g. 6 digits), distribute starting at 0
    final targetStart = digits.length >= widget.length ? 0 : startIndex;

    for (int i = 0; i < widget.length; i++) {
      final digitIndex = i - targetStart;
      if (digitIndex >= 0 && digitIndex < digits.length) {
        _boxControllers[i].text = digits[digitIndex];
      }
    }

    if (targetStart + digits.length >= widget.length) {
      _focusNodes[widget.length - 1].unfocus();
    } else {
      final nextFocus = (targetStart + digits.length).clamp(0, widget.length - 1);
      _focusNodes[nextFocus].requestFocus();
    }

    _notifyChanged();
  }

  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_boxControllers[index].text.isEmpty && index > 0) {
        _boxControllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        _notifyChanged();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            // Cap the row width on large screens/tablets so boxes don't get overly wide
            final maxRowWidth = availableWidth.clamp(0.0, 360.0);
            // Adaptive spacing based on available width
            final spacing = (maxRowWidth < 300) ? 6.0 : 8.0;

            return Center(
              child: SizedBox(
                width: maxRowWidth,
                child: Row(
                  children: [
                    for (int i = 0; i < widget.length; i++) ...[
                      if (i > 0) SizedBox(width: spacing),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 0.82,
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.enabled
                                  ? Colors.white
                                  : AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasError
                                    ? AppColors.error
                                    : _focusedIndex == i
                                        ? (widget.activeBorderColor ?? AppColors.primary)
                                        : _boxControllers[i].text.isNotEmpty
                                            ? (widget.activeBorderColor ?? AppColors.primary).withValues(alpha: 0.45)
                                            : AppColors.border,
                                width: _focusedIndex == i
                                    ? 2.0
                                    : (hasError ? 1.5 : 1.0),
                              ),
                              boxShadow: _focusedIndex == i
                                  ? [
                                      BoxShadow(
                                        color: (widget.activeBorderColor ?? AppColors.primary).withValues(alpha: 0.16),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Theme(
                              // Override inputDecorationTheme completely to eliminate inherited black borders
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: const InputDecorationTheme(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                ),
                              ),
                              child: TextField(
                                controller: _boxControllers[i],
                                focusNode: _focusNodes[i],
                                enabled: widget.enabled,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: AppColors.primary,
                                cursorWidth: 2.0,
                                showCursor: _focusedIndex == i,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.1,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(widget.length),
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                onChanged: (val) => _onBoxChanged(i, val),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
