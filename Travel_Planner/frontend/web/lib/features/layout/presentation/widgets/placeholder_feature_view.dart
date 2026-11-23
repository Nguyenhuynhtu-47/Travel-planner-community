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
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tab.icon, size: 32, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tab.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhóm: ${tab.group.label}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_outlined, size: 14, color: Colors.amber.shade900),
                            const SizedBox(width: 4),
                            Text(
                              'Chưa triển khai',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 36, color: AppColors.border),
                  const Text(
                    'Lộ trình chức năng dự kiến:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...planned.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textBody,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairlineSoft),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Module này đang chờ bổ sung các endpoint API chuyên biệt tại Backend. Khi API hoàn tất, giao diện sẽ được tích hợp trực tiếp, không sử dụng dữ liệu giả lập.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.dashboard_outlined, size: 18),
                        label: const Text('Quay lại Dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      ),
    );
  }
}
