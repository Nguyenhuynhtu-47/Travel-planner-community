import 'package:flutter/material.dart';

/// Semantic status badge for Admin tables and detail views.
/// Uses soft background tints and 1px borders with readable semantic typography.
class AdminStatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const AdminStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final upper = status.trim().toUpperCase();
    final (bgColor, borderColor, textColor, label) = _getStyle(upper);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        customLabel ?? label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  (Color, Color, Color, String) _getStyle(String s) {
    switch (s) {
      case 'ACTIVE':
      case 'RESOLVED':
      case 'UP':
        return (
          const Color(0xFFECFDF5),
          const Color(0xFFA7F3D0),
          const Color(0xFF047857),
          s == 'ACTIVE' ? 'Hoạt động' : s == 'RESOLVED' ? 'Đã xử lý' : 'Trực tuyến',
        );
      case 'HIDDEN':
      case 'WARNING':
        return (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          const Color(0xFFB45309),
          s == 'HIDDEN' ? 'Đã ẩn' : 'Cảnh báo',
        );
      case 'PENDING':
        return (
          const Color(0xFFFEF3C7),
          const Color(0xFFFCD34D),
          const Color(0xFF92400E),
          'Chờ xử lý',
        );
      case 'DELETED':
      case 'BANNED':
      case 'PURGED':
      case 'DEAD_LETTER':
      case 'ERROR':
        return (
          const Color(0xFFFEF2F2),
          const Color(0xFFFECACA),
          const Color(0xFFB91C1C),
          s == 'DELETED'
              ? 'Đã xóa'
              : s == 'BANNED'
                  ? 'Đã khóa'
                  : s == 'DEAD_LETTER'
                      ? 'Dead-Letter'
                      : s,
        );
      case 'DISMISSED':
      case 'INACTIVE':
        return (
          const Color(0xFFF3F4F6),
          const Color(0xFFE5E7EB),
          const Color(0xFF4B5563),
          s == 'DISMISSED' ? 'Đã bỏ qua' : 'Vô hiệu hóa',
        );
      case 'ATTACHED':
        return (
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          const Color(0xFF15803D),
          'Đã gắn bài',
        );
      case 'UNATTACHED':
        return (
          const Color(0xFFEFF6FF),
          const Color(0xFFBFDBFE),
          const Color(0xFF1D4ED8),
          'Chưa gán',
        );
      case 'DELETING':
        return (
          const Color(0xFFFFF1F2),
          const Color(0xFFFECDD3),
          const Color(0xFFBE123C),
          'Đang xóa',
        );
      default:
        return (
          const Color(0xFFF9FAFB),
          const Color(0xFFE5E7EB),
          const Color(0xFF374151),
          s,
        );
    }
  }
}
