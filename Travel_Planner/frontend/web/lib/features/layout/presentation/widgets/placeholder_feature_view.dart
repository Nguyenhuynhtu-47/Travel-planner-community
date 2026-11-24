import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/shared/widgets/app_primary_button.dart';

class PlaceholderFeatureView extends StatelessWidget {
  final AdminTab tab;
  final VoidCallback onGoToDashboard;

  const PlaceholderFeatureView({
    super.key,
    required this.tab,
    required this.onGoToDashboard,
  });

  List<String> _getPlannedFeatures() {
    switch (tab) {
      case AdminTab.users:
        return [
          'Danh sách tài khoản người dùng toàn hệ thống có phân trang & tìm kiếm.',
          'Xem thông tin chi tiết hồ sơ, ngày đăng ký, trạng thái hoạt động.',
          'Khóa tài khoản (Ban/Deactivate) vi phạm tiêu chuẩn cộng đồng.',
          'Nâng cấp / Giáng cấp phân quyền vai trò (USER ↔ ADMIN).',
          'Lịch sử báo cáo vi phạm liên quan đến người dùng.',
        ];
      case AdminTab.itineraries:
        return [
          'Quản lý danh sách các lịch trình du lịch công khai của cộng đồng.',
          'Kiểm duyệt và ẩn các lịch trình vi phạm, spam hoặc nội dung không hợp lệ.',
          'Đánh dấu / Ghim lịch trình nổi bật lên trang khám phá cộng đồng.',
          'Thống kê số lượt lưu, tải và sao chép lịch trình theo vùng miền.',
        ];
      case AdminTab.administrativeAreas:
        return [
          'Tra cứu cấu trúc cây hành chính 34 tỉnh/thành phố và các đơn vị trực thuộc.',
          'Xem báo cáo tỷ lệ liên kết địa điểm chuẩn hóa với đơn vị hành chính.',
          'Kích hoạt tiến trình Batch Resolve tự động cho các địa điểm chưa liên kết.',
          'Quản lý mã đơn vị hành chính chuẩn quốc gia theo quy định Bộ Nội vụ.',
        ];
      case AdminTab.auditLogs:
        return [
          'Nhật ký toàn bộ thao tác quản trị: Ẩn bài viết, Xử lý báo cáo, Sửa địa điểm.',
          'Ghi nhận thông tin Quản trị viên thực hiện, địa chỉ IP và dấu mốc thời gian.',
          'Truy vết các thay đổi dữ liệu nhạy cảm trên hệ thống.',
          'Xuất dữ liệu kiểm toán (Audit Trail Export) định dạng CSV / JSON.',
        ];
      case AdminTab.settings:
        return [
          'Cấu hình giới hạn kích thước và định dạng tệp tải lên (Media Upload limits).',
          'Quản lý khóa API tích hợp: TomTom Maps, Cloudinary Media CDN.',
          'Thiết lập ngưỡng tin cậy (Confidence Threshold) cho liên kết địa lý tự động.',
          'Tùy chỉnh thông báo hệ thống và thời gian lưu trữ nhật ký.',
        ];
      default:
        return [
          'Tính năng đang trong lộ trình phát triển và hoàn thiện kỹ thuật.',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final planned = _getPlannedFeatures();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(tab.icon, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tab.title,
                            style: AppTypography.titleSection,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nhóm: ${tab.group.label}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.warningBorder, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_outlined, size: 12, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Chưa triển khai',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: AppColors.border),
                const Text(
                  'Lộ trình chức năng dự kiến:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...planned.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: AppTypography.bodyData.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppPrimaryButton(
                    text: 'Quay lại trang Tổng quan',
                    icon: Icons.dashboard_outlined,
                    onPressed: onGoToDashboard,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
