import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';

/// Semantic status badge for Admin tables and detail views.
/// Uses soft background tints, 1px hairline borders, and accessible typography.
/// Follows Swiss Minimalist 4px micro-radius geometry without pill shapes.
class AdminStatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const AdminStatusBadge({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    final upper = status.trim().toUpperCase();
    final (bgColor, borderColor, textColor, label) = _getStyle(upper);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        customLabel ?? label,
        style: AppTypography.badgeMicro.copyWith(color: textColor),
      ),
    );
  }

  (Color, Color, Color, String) _getStyle(String s) {
    switch (s) {
      case 'ACTIVE':
      case 'RESOLVED':
      case 'UP':
        return (
          AppColors.successLight,
          AppColors.successBorder,
          AppColors.success,
          s == 'ACTIVE'
              ? 'Hoạt động'
              : s == 'RESOLVED'
              ? 'Đã xử lý'
              : 'Trực tuyến',
        );
      case 'PENDING':
      case 'DRAFT':
        return (
          AppColors.warningLight,
          AppColors.warningBorder,
          AppColors.warning,
          s == 'DRAFT' ? 'Chờ công khai' : 'Chờ xử lý',
        );
      case 'PUBLISHED':
        return (
          AppColors.successLight,
          AppColors.successBorder,
          AppColors.success,
          'Đã công khai',
        );
      case 'CANCELLED':
        return (
          AppColors.surfaceHover,
          AppColors.borderStrong,
          AppColors.textSecondary,
          'Đã hủy',
        );
      case 'EXPIRED':
        return (
          AppColors.errorLight,
          AppColors.errorBorder,
          AppColors.error,
          'Đã hết hạn',
        );
      case 'HIDDEN':
      case 'WARNING':
        return (
          AppColors.warningLight,
          AppColors.warningBorder,
          AppColors.warning,
          s == 'HIDDEN' ? 'Đã ẩn' : 'Cảnh báo',
        );
      case 'DELETED':
      case 'BANNED':
      case 'PURGED':
      case 'DEAD_LETTER':
      case 'ERROR':
        return (
          AppColors.errorLight,
          AppColors.errorBorder,
          AppColors.error,
          s == 'DELETED'
              ? 'Đã xóa'
              : s == 'BANNED'
              ? 'Đã khóa'
              : s == 'PURGED'
              ? 'Đã xóa vĩnh viễn'
              : s == 'DEAD_LETTER'
              ? 'Lỗi đình trệ'
              : s,
        );
      case 'DISMISSED':
      case 'INACTIVE':
        return (
          AppColors.surfaceHover,
          AppColors.borderStrong,
          AppColors.textSecondary,
          s == 'DISMISSED' ? 'Đã bỏ qua' : 'Vô hiệu hóa',
        );
      case 'ATTACHED':
        return (
          AppColors.successLight,
          AppColors.successBorder,
          AppColors.success,
          'Đã gắn bài',
        );
      case 'UNATTACHED':
        return (
          AppColors.infoLight,
          AppColors.infoBorder,
          AppColors.info,
          'Chưa gán',
        );
      case 'DELETING':
        return (
          AppColors.accentLight,
          AppColors.accentBorder,
          AppColors.accentDark,
          'Đang xóa...',
        );
      default:
        return (
          AppColors.surfaceHover,
          AppColors.border,
          AppColors.textSecondary,
          s,
        );
    }
  }
}
