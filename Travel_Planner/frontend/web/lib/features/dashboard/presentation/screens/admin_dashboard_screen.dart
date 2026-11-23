import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/dashboard/data/dashboard_repository.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_report_model.dart';
import 'package:travel_planner_web/shared/widgets/admin_page_header.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final DashboardRepository? repository;
  final ValueChanged<AdminTab> onNavigateTab;

  const AdminDashboardScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    required this.onNavigateTab,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final DashboardRepository _repository;
  bool _isLoading = true;
  AdminDashboardData _data = AdminDashboardData.empty();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DashboardRepository();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = widget.authNotifier.token;
      final data = await _repository.fetchDashboardData(token);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
          _errorMessage = data.errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải số liệu bảng điều khiển: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authNotifier.currentUser;
    final fullName =
        user?['fullName'] ?? user?['username'] ?? 'Quản trị viên';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Flat SaaS Page Header
          AdminPageHeader(
            title: 'Tổng quan Dashboard',
            subtitle: 'Trung tâm Quản trị Travel Planner — Dữ liệu vận hành thời gian thực.',
            actions: [
              Text(
                'Xin chào, $fullName!',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Làm mới', style: TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _loadDashboardData,
              ),
            ],
          ),

          // Main scrollable workspace
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_errorMessage != null)
                      _buildErrorBanner()
                    else ...[
                      // Unified SaaS Metric Strip
                      _buildMetricStrip(),
                      const SizedBox(height: 20),

                      // Two-column Data Workspace (Pending Reports & Recent Posts)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 960) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildRecentReportsCard(_data.recentPendingReports),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildRecentPostsCard(_data.recentPosts),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _buildRecentReportsCard(_data.recentPendingReports),
                              const SizedBox(height: 20),
                              _buildRecentPostsCard(_data.recentPosts),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Đã xảy ra lỗi khi tải dữ liệu',
              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: _loadDashboardData,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Unified statistics band (SaaS metric strip)
  Widget _buildMetricStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final items = [
          _MetricItemData(
            title: 'Địa điểm chuẩn hóa',
            value: _data.placesCount.toString(),
            subtitle: 'Địa điểm đã số hóa',
            onTap: () => widget.onNavigateTab(AdminTab.places),
          ),
          _MetricItemData(
            title: 'Bài viết cộng đồng',
            value: _data.postsCount.toString(),
            subtitle: 'Bài viết trên hệ thống',
            onTap: () => widget.onNavigateTab(AdminTab.posts),
          ),
          _MetricItemData(
            title: 'Báo cáo chờ xử lý',
            value: _data.pendingReportsCount.toString(),
            subtitle: _data.pendingReportsCount > 0
                ? 'Cần quản trị viên duyệt'
                : 'Không có báo cáo tồn',
            isAlert: _data.pendingReportsCount > 0,
            onTap: () => widget.onNavigateTab(AdminTab.reports),
          ),
          _MetricItemData(
            title: 'Tài nguyên Media',
            value: _data.mediaAssetsCount.toString(),
            subtitle: 'Hình ảnh đính kèm',
            onTap: () => widget.onNavigateTab(AdminTab.media),
          ),
        ];

        if (isWide) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                    Expanded(child: _buildMetricCell(items[i])),
                  ],
                ],
              ),
            ),
          );
        }

        // Narrow screen: 2x2 grid in a clean bordered container
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildMetricCell(items[0])),
                  Container(width: 1, height: 90, color: AppColors.border),
                  Expanded(child: _buildMetricCell(items[1])),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              Row(
                children: [
                  Expanded(child: _buildMetricCell(items[2])),
                  Container(width: 1, height: 90, color: AppColors.border),
                  Expanded(child: _buildMetricCell(items[3])),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCell(_MetricItemData data) {
    return InkWell(
      onTap: data.onTap,
      hoverColor: AppColors.surfaceSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: data.isAlert ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 13,
                  color: data.isAlert ? AppColors.error : AppColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data.value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: data.isAlert ? AppColors.error : AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReportsCard(List<AdminPostReportModel> reports) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Báo cáo vi phạm đang chờ xử lý',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (reports.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          '${reports.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(AdminTab.reports),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Tất cả báo cáo →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 24, color: AppColors.success),
                    SizedBox(height: 6),
                    Text(
                      'Không có báo cáo vi phạm nào đang chờ xử lý',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.hairlineSoft),
              itemBuilder: (context, index) {
                final report = reports[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '#${report.reportId}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.reason.isNotEmpty ? report.reason : '(Không có lý do)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bài viết #${report.postId} • Người báo: @${report.reporter?.handle ?? 'ẩn danh'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.onNavigateTab(AdminTab.reports),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('Xử lý', style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentPostsCard(List<AdminPostModel> posts) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bài viết cộng đồng gần đây',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(AdminTab.posts),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Xem tất cả →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'Chưa có bài viết nào trên hệ thống',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.hairlineSoft),
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.surfaceSoft,
                        child: Text(
                          post.author.displayName.isNotEmpty
                              ? post.author.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.content.isNotEmpty ? post.content : '(Đính kèm hình ảnh/lịch trình)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${post.author.handle} • ${post.mediaUrls.length} ảnh',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AdminStatusBadge(status: post.status),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MetricItemData {
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;
  final bool isAlert;

  _MetricItemData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
    this.isAlert = false,
  });
}
