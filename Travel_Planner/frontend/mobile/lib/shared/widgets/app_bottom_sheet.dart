import 'package:flutter/material.dart';

import 'bounce_tap.dart';

/// Option item for [AppBottomSheet.showOptions].
class AppBottomSheetOption<T> {
  final IconData icon;
  final String label;
  final String? subtitle;
  final T? value;
  final VoidCallback? onTap;
  final bool isDestructive;

  const AppBottomSheetOption({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.onTap,
    this.isDestructive = false,
  });
}

/// Standardized modal bottom sheet system for Travel Planner.
///
/// Features:
/// - Pure white `#FFFFFF` surface with 24px top corner radius
/// - Centered 40x4px drag handle (`#D1D5DB`)
/// - Optional bold title (`17px`, `#1E1E1E`) with `#F3F4F6` divider
/// - Automatic keyboard `viewInsets.bottom` + bottom `SafeArea` padding
class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    bool useSafeArea = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDragHandle)
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  if (title != null) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        showDragHandle ? 4 : 16,
                        20,
                        12,
                      ),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E1E),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF3F4F6),
                    ),
                  ],
                  Flexible(
                    child: builder(sheetContext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Displays a standardized list of action options with icon badges and [BounceTap].
  static Future<T?> showOptions<T>(
    BuildContext context, {
    String? title,
    required List<AppBottomSheetOption<T>> options,
  }) {
    return show<T>(
      context,
      title: title,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              AppBottomSheetOptionTile(
                icon: option.icon,
                label: option.label,
                subtitle: option.subtitle,
                isDestructive: option.isDestructive,
                onTap: () {
                  Navigator.of(sheetContext).pop(option.value);
                  option.onTap?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Standardized option row inside [AppBottomSheet] with a 10px-radius icon badge
/// and [BounceTap] tactile feedback.
class AppBottomSheetOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const AppBottomSheetOptionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isDestructive ? const Color(0xFFFA3E62) : const Color(0xFF4B5563);
    final badgeColor =
        isDestructive ? const Color(0xFFFFF0F3) : const Color(0xFFF3F4F6);
    final textColor =
        isDestructive ? const Color(0xFFFA3E62) : const Color(0xFF1E1E1E);

    return BounceTap(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
