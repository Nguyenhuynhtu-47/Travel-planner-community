import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/dashboard/data/dashboard_repository.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_model.dart';
import 'package:travel_planner_web/features/moderation/data/models/admin_post_report_model.dart';
import 'package:travel_planner_web/shared/widgets/admin_page_header.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';
import 'package:travel_planner_web/shared/widgets/hover_movement.dart';

/// Professional Enterprise Operations Dashboard for Travel Planner Admin.
/// Aligned with docs/plan/admin-design-system.md (Swiss Minimalist / Real-time SaaS).
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
  DateTime? _lastRefreshedAt;

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
          _lastRefreshedAt = DateTime.now();
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
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
            title: 'Tổng quan',
            subtitle: 'Trung tâm Quản trị Travel Planner — Dữ liệu vận hành thời gian thực.',
            actions: [
              Text(
                'Xin chào, $fullName!',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_lastRefreshedAt != null) ...[
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Text(
                    'Cập nhật: ${_formatTime(_lastRefreshedAt)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              HoverMovement.button(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _loadDashboardData,
                ),
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
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (_errorMessage != null)
                      _buildErrorBanner()
                    else ...[
                      // Unified SaaS Metric Strip
                      _buildMetricStrip(),
                      const SizedBox(height: AppSpacing.xl),

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
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(
                                  child: _buildRecentPostsCard(_data.recentPosts),
                                ),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildRecentReportsCard(_data.recentPendingReports),
                              const SizedBox(height: AppSpacing.xl),
                              _buildRecentPostsCard(_data.recentPosts),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // System Telemetry & Operational Health Strip
                      _buildSystemTelemetryBar(),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.errorBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _errorMessage ?? 'Đã xảy ra lỗi khi tải dữ liệu',
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadDashboardData,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Thử lại',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
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
            subtitle: 'Cơ sở dữ liệu địa điểm du lịch',
            icon: Icons.place_outlined,
            onTap: () => widget.onNavigateTab(AdminTab.places),
          ),
          _MetricItemData(
            title: 'Bài viết cộng đồng',
            value: _data.postsCount.toString(),
            subtitle: 'Bài đăng du lịch trên hệ thống',
            icon: Icons.article_outlined,
            onTap: () => widget.onNavigateTab(AdminTab.posts),
          ),
          _MetricItemData(
            title: 'Báo cáo chờ xử lý',
            value: _data.pendingReportsCount.toString(),
            subtitle: _data.pendingReportsCount > 0
                ? 'Cần quản trị viên duyệt ngay'
                : 'Không có báo cáo tồn đọng',
            icon: Icons.report_problem_outlined,
            isAlert: _data.pendingReportsCount > 0,
            onTap: () => widget.onNavigateTab(AdminTab.reports),
          ),
          _MetricItemData(
            title: 'Tài nguyên Media',
            value: _data.mediaAssetsCount.toString(),
            subtitle: 'Hình ảnh đính kèm Cloudinary',
            icon: Icons.perm_media_outlined,
            onTap: () => widget.onNavigateTab(AdminTab.media),
          ),
        ];

        if (isWide) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                    Expanded(child: _MetricCellWidget(data: items[i])),
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
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _MetricCellWidget(data: items[0])),
                  Container(width: 1, height: 96, color: AppColors.border),
                  Expanded(child: _MetricCellWidget(data: items[1])),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              Row(
                children: [
                  Expanded(child: _MetricCellWidget(data: items[2])),
                  Container(width: 1, height: 96, color: AppColors.border),
                  Expanded(child: _MetricCellWidget(data: items[3])),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentReportsCard(List<AdminPostReportModel> reports) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Báo cáo vi phạm đang chờ xử lý',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (reports.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.accentBorder, width: 1),
                          ),
                          child: Text(
                            '${reports.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => widget.onNavigateTab(AdminTab.reports),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primaryAccessible,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text(
                    'Tất cả báo cáo →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
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
                        color: AppColors.textMuted,
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
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.hairlineSoft,
              ),
              itemBuilder: (context, index) {
                final report = reports[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(color: AppColors.warningBorder, width: 1),
                        ),
                        child: Text(
                          '#${report.reportId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
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
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.onNavigateTab(AdminTab.reports),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderStrong),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        child: const Text(
                          'Xử lý',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                        ),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Bài viết cộng đồng gần đây',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => widget.onNavigateTab(AdminTab.posts),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primaryAccessible,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text(
                    'Xem tất cả →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
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
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.hairlineSoft,
              ),
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          post.author.displayName.isNotEmpty
                              ? post.author.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
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
                                color: AppColors.textMuted,
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

  /// System Telemetry & Operational Health Strip
  Widget _buildSystemTelemetryBar() {
    final isUp = _data.healthStatus == 'UP';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 768;

          final healthCol = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUp ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Dịch vụ: ${_data.serviceName ?? 'travel-planner-backend'} (${_data.healthStatus})',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isUp ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          );

          final serverTimeCol = Text(
            'Thời gian máy chủ: ${_data.serverTimestamp ?? 'Chưa xác định'}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                healthCol,
                const SizedBox(height: 4),
                serverTimeCol,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              healthCol,
              serverTimeCol,
            ],
          );
        },
      ),
    );
  }
}

class _MetricItemData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAlert;

  _MetricItemData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isAlert = false,
  });
}

class _MetricCellWidget extends StatefulWidget {
  final _MetricItemData data;
  const _MetricCellWidget({required this.data});

  @override
  State<_MetricCellWidget> createState() => _MetricCellWidgetState();
}

class _MetricCellWidgetState extends State<_MetricCellWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isHovered = _isHovered;

    final valueColor = data.isAlert ? AppColors.accentDark : AppColors.textPrimary;
    final iconBgColor = data.isAlert
        ? AppColors.primaryLight
        : (isHovered ? AppColors.primaryTint : AppColors.surfaceSubtle);
    final iconColor = data.isAlert
        ? AppColors.primaryAccessible
        : (isHovered ? AppColors.primaryAccessible : AppColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: data.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0.0, isHovered ? -2.0 : 0.0, 0.0),
          color: isHovered ? AppColors.primaryTint : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: isHovered
                          ? Border.all(color: AppColors.primaryBorder, width: 1)
                          : null,
                    ),
                    child: Icon(data.icon, size: 14, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: data.isAlert
                            ? AppColors.accentDark
                            : (isHovered ? AppColors.primaryAccessible : AppColors.textSecondary),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 13,
                    color: isHovered
                        ? AppColors.primaryAccessible
                        : (data.isAlert ? AppColors.primaryAccessible : AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: data.isAlert ? AppColors.accentDark : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
