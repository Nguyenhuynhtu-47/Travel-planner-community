import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';

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
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(24),
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
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(tab.icon, size: 22, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tab.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nhóm: ${tab.group.label}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_outlined, size: 12, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Chưa triển khai',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...planned.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_outline, size: 15, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textBody,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.hairlineSoft),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Module này đang chờ bổ sung các endpoint API chuyên biệt tại Backend. Khi API hoàn tất, giao diện sẽ được tích hợp trực tiếp, không sử dụng dữ liệu giả lập.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.dashboard_outlined, size: 16),
                      label: const Text('Quay lại Dashboard', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: onGoToDashboard,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
