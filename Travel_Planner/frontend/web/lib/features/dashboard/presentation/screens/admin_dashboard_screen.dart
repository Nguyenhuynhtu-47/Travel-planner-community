import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/dashboard/data/dashboard_repository.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_report_model.dart';

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
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              _buildWelcomeBanner(fullName),
              const SizedBox(height: 24),

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
                // Stat cards
                _buildStatCards(),
                const SizedBox(height: 28),

                // Quick action bar
                _buildQuickActions(),
                const SizedBox(height: 28),

                // Live split sections: Pending Reports & Recent Posts
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 980) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildRecentReportsCard(_data.recentPendingReports),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildRecentPostsCard(_data.recentPosts),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildRecentReportsCard(_data.recentPendingReports),
                        const SizedBox(height: 24),
                        _buildRecentPostsCard(_data.recentPosts),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Backend health & system info card
                _buildSystemStatusCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String fullName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Xin chào, $fullName!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Trung tâm Quản trị Travel Planner — Dữ liệu vận hành được cập nhật trực tiếp từ hệ thống.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Làm mới'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Đã xảy ra lỗi khi tải dữ liệu',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: _loadDashboardData,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1000
            ? (constraints.maxWidth - 48) / 4
            : constraints.maxWidth >= 600
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Địa điểm chuẩn hóa',
                value: _data.placesCount.toString(),
                subtitle: 'Địa điểm đã số hóa',
                icon: Icons.place_outlined,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                onTap: () => widget.onNavigateTab(AdminTab.places),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Bài viết cộng đồng',
                value: _data.postsCount.toString(),
                subtitle: 'Bài viết trên hệ thống',
                icon: Icons.article_outlined,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                onTap: () => widget.onNavigateTab(AdminTab.posts),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Báo cáo chờ xử lý',
                value: _data.pendingReportsCount.toString(),
                subtitle: _data.pendingReportsCount > 0
                    ? 'Cần quản trị viên duyệt'
                    : 'Không có báo cáo tồn',
                icon: Icons.report_problem_outlined,
                iconColor: _data.pendingReportsCount > 0
                    ? AppColors.error
                    : AppColors.success,
                iconBg: _data.pendingReportsCount > 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFECFDF5),
                highlight: _data.pendingReportsCount > 0,
                onTap: () => widget.onNavigateTab(AdminTab.reports),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Tài nguyên Media',
                value: _data.mediaAssetsCount.toString(),
                subtitle: 'Hình ảnh đính kèm',
                icon: Icons.perm_media_outlined,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFECFDF5),
                onTap: () => widget.onNavigateTab(AdminTab.media),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? AppColors.error.withAlpha(100) : AppColors.border,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const Icon(Icons.arrow_forward, size: 16, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lối tắt thao tác nhanh',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ActionChip(
                avatar: const Icon(Icons.article_outlined, size: 16, color: AppColors.primary),
                label: const Text('Kiểm duyệt bài viết'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => widget.onNavigateTab(AdminTab.posts),
              ),
              ActionChip(
                avatar: const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.warning),
                label: const Text('Xử lý báo cáo vi phạm'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => widget.onNavigateTab(AdminTab.reports),
              ),
              ActionChip(
                avatar: const Icon(Icons.place_outlined, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Quản lý địa điểm chuẩn hóa'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => widget.onNavigateTab(AdminTab.places),
              ),
              ActionChip(
                avatar: const Icon(Icons.perm_media_outlined, size: 16, color: Color(0xFF059669)),
                label: const Text('Quản lý tài nguyên Media'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => widget.onNavigateTab(AdminTab.media),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReportsCard(List<AdminPostReportModel> reports) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.report_outlined, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Báo cáo vi phạm đang chờ xử lý',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(AdminTab.reports),
                child: const Text('Tất cả báo cáo →', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 36, color: AppColors.success),
                    SizedBox(height: 8),
                    Text(
                      'Không có báo cáo vi phạm nào đang chờ xử lý',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...reports.map((report) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hairlineSoft),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${report.reportId}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bài viết #${report.postId} • Người báo cáo: @${report.reporter?.handle ?? 'ẩn danh'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab(AdminTab.reports),
                        child: const Text('Xử lý', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildRecentPostsCard(List<AdminPostModel> posts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.article_outlined, size: 20, color: Color(0xFF7C3AED)),
                  SizedBox(width: 8),
                  Text(
                    'Bài viết cộng đồng gần đây',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(AdminTab.posts),
                child: const Text('Xem tất cả →', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Chưa có bài viết nào trên hệ thống',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...posts.map((post) {
              final isActive = post.status == 'ACTIVE';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.purple.shade50,
                      child: Text(
                        post.author.displayName.isNotEmpty
                            ? post.author.displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.content.isNotEmpty ? post.content : '(Đính kèm media)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tác giả: @${post.author.handle} • ${post.mediaUrls.length} ảnh',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    final isOnline = _data.healthStatus == 'UP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dns_outlined, size: 20, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text(
                'Thông tin kết nối & Trạng thái Hệ thống',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Dịch vụ Backend: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    _data.serviceName ?? 'travel-planner-backend',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái API: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFFECFDF5) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOnline ? 'UP (Hoạt động bình thường)' : _data.healthStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? AppColors.success : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              if (_data.serverTimestamp != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Dấu mốc máy chủ: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text(
                      _data.serverTimestamp!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
