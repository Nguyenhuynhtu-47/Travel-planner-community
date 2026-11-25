import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/audit_logs/data/models/audit_log_model.dart';
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
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DashboardRepository();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData({int? days}) async {
    final targetDays = days ?? _selectedDays;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedDays = targetDays;
    });

    try {
      final token = widget.authNotifier.token;
      final data = await _repository.fetchDashboardData(
        token,
        days: targetDays,
      );
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
    final fullName = user?['fullName'] ?? user?['username'] ?? 'Quản trị viên';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Flat SaaS Page Header
          AdminPageHeader(
            title: 'Tổng quan',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                      // Unified SaaS Metric Strip (6 core operational groups)
                      _buildMetricStrip(),
                      const SizedBox(height: AppSpacing.xl),

                      // Phase 7 Analytics: Growth Charts + Recent Audit Trail Feed
                      _buildAnalyticsAndAuditSection(),
                      const SizedBox(height: AppSpacing.xl),

                      // Legacy / Operational Workspaces (Pending Reports & Recent Posts when present)
                      if (_data.recentPendingReports.isNotEmpty ||
                          _data.recentPosts.isNotEmpty) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 960) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildRecentReportsCard(
                                      _data.recentPendingReports,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xl),
                                  Expanded(
                                    child: _buildRecentPostsCard(
                                      _data.recentPosts,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildRecentReportsCard(
                                  _data.recentPendingReports,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                _buildRecentPostsCard(_data.recentPosts),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
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

  /// Unified statistics band (6 core operational groups - Phase 7 ID 7.7)
  Widget _buildMetricStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1060;
        final isMedium = constraints.maxWidth >= 680;

        final items = [
          _MetricItemData(
            title: 'Người dùng hệ thống',
            value: _data.totalUsers.toString(),
            subtitle:
                '${_data.activeUsers} hoạt động • ${_data.bannedUsers} bị khóa',
            icon: Icons.people_outline,
            accentColor: const Color(0xFF2563EB),
            tintColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            onTap: () => widget.onNavigateTab(AdminTab.users),
          ),
          _MetricItemData(
            title: 'Địa điểm chuẩn hóa',
            value: _data.placesCount.toString(),
            subtitle:
                '${_data.activePlaces} hoạt động • ${_data.placeAreaCoveragePercentage.toStringAsFixed(1)}% ĐVHC',
            icon: Icons.place_outlined,
            accentColor: const Color(0xFF15803D),
            tintColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            onTap: () => widget.onNavigateTab(AdminTab.places),
          ),
          _MetricItemData(
            title: 'Lịch trình du lịch',
            value: _data.totalItineraries.toString(),
            subtitle:
                '${_data.publicItineraries} công khai • ${_data.hiddenItineraries} đã ẩn',
            icon: Icons.map_outlined,
            accentColor: const Color(0xFF7C3AED),
            tintColor: const Color(0xFFF5F3FF),
            borderColor: const Color(0xFFDDD6FE),
            onTap: () => widget.onNavigateTab(AdminTab.itineraries),
          ),
          _MetricItemData(
            title: 'Bài viết cộng đồng',
            value: _data.postsCount.toString(),
            subtitle: _data.hiddenPosts > 0
                ? '${_data.hiddenPosts} bài viết đã ẩn'
                : 'Bài đăng du lịch trên hệ thống',
            icon: Icons.article_outlined,
            accentColor: const Color(0xFFDB2777),
            tintColor: const Color(0xFFFDF2F8),
            borderColor: const Color(0xFFFBCFE8),
            onTap: () => widget.onNavigateTab(AdminTab.posts),
          ),
          _MetricItemData(
            title: 'Báo cáo chờ xử lý',
            value: _data.pendingReportsCount.toString(),
            subtitle: _data.pendingReportsCount > 0
                ? 'Cần quản trị viên duyệt ngay'
                : 'Không có báo cáo tồn đọng',
            icon: Icons.report_problem_outlined,
            accentColor: const Color(0xFFD97706),
            tintColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            isAlert: _data.pendingReportsCount > 0,
            onTap: () => widget.onNavigateTab(AdminTab.reports),
          ),
          _MetricItemData(
            title: 'Tài nguyên Media',
            value: _data.mediaAssetsCount.toString(),
            subtitle: _data.deadLetterMediaAssets > 0
                ? '${_data.deadLetterMediaAssets} ảnh lỗi / dead-letter'
                : 'Hình ảnh đính kèm Cloudinary',
            icon: Icons.perm_media_outlined,
            accentColor: const Color(0xFF0F766E),
            tintColor: const Color(0xFFF0FDFA),
            borderColor: const Color(0xFF99F6E4),
            isAlert: _data.deadLetterMediaAssets > 0,
            onTap: () => widget.onNavigateTab(AdminTab.media),
          ),
        ];

        final int cols = isWide ? 3 : (isMedium ? 2 : 1);
        final rows = <Widget>[];
        for (int i = 0; i < items.length; i += cols) {
          if (i > 0) {
            rows.add(const SizedBox(height: AppSpacing.md));
          }
          final rowChildren = <Widget>[];
          for (int c = 0; c < cols; c++) {
            if (c > 0) {
              rowChildren.add(const SizedBox(width: AppSpacing.md));
            }
            if (i + c < items.length) {
              rowChildren.add(
                Expanded(child: _MetricCellWidget(data: items[i + c])),
              );
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          rows.add(IntrinsicHeight(child: Row(children: rowChildren)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  /// Phase 7 ID 7.8: Real-Data Growth Charts + Recent Audit Trail Feed
  Widget _buildAnalyticsAndAuditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time range filter bar shared across both charts
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insights_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Thống kê hoạt động hệ thống',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_data.analyticsFromDate != null &&
                      _data.analyticsToDate != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      '(${_data.analyticsFromDate} → ${_data.analyticsToDate})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 6,
                children: [7, 30, 90].map((d) {
                  final selected = _selectedDays == d;
                  return ChoiceChip(
                    label: Text('$d ngày'),
                    selected: selected,
                    onSelected: (val) {
                      if (val && _selectedDays != d) {
                        _loadDashboardData(days: d);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 960) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildGrowthChartCard(
                      title: 'Người dùng mới đăng ký theo ngày',
                      unitLabel: 'Đơn vị: tài khoản / ngày',
                      legendLabel: 'Đăng ký mới',
                      emptyMessage: 'Chưa có lượt đăng ký mới trong khoảng thời gian này.',
                      points: _data.userRegistrationsDaily,
                      barColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: _buildGrowthChartCard(
                      title: 'Bài viết cộng đồng chia sẻ theo tuần',
                      unitLabel: 'Đơn vị: bài viết / tuần',
                      legendLabel: 'Bài viết mới',
                      emptyMessage:
                          'Chưa có bài viết mới trong khoảng thời gian này.',
                      points: _data.communityPostsWeekly,
                      barColor: AppColors.success,
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGrowthChartCard(
                  title: 'Người dùng mới đăng ký theo ngày',
                  unitLabel: 'Đơn vị: tài khoản / ngày',
                  legendLabel: 'Đăng ký mới',
                  emptyMessage:
                      'Chưa có lượt đăng ký mới trong khoảng thời gian này.',
                  points: _data.userRegistrationsDaily,
                  barColor: const Color(0xFF2563EB),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildGrowthChartCard(
                  title: 'Bài viết cộng đồng chia sẻ theo tuần',
                  unitLabel: 'Đơn vị: bài viết / tuần',
                  legendLabel: 'Bài viết mới',
                  emptyMessage:
                      'Chưa có bài viết mới trong khoảng thời gian này.',
                  points: _data.communityPostsWeekly,
                  barColor: AppColors.success,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 960) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildItineraryDistributionCard()),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: _buildTopPlacesCard()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildItineraryDistributionCard(),
                const SizedBox(height: AppSpacing.md),
                _buildTopPlacesCard(),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildRecentAuditLogsCard(_data.recentAuditLogs),
      ],
    );
  }

  Widget _buildGrowthChartCard({
    required String title,
    required String unitLabel,
    required String legendLabel,
    required String emptyMessage,
    required List<DashboardTimeSeriesPoint> points,
    required Color barColor,
  }) {
    final total = points.fold<int>(0, (acc, p) => acc + p.count);
    final maxVal = points.fold<int>(1, (m, p) => p.count > m ? p.count : m);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unitLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: barColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$legendLabel • Tổng: $total',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((pt) {
                  final ratio = pt.count / maxVal;
                  final barHeight = (ratio * 96.0).clamp(3.0, 96.0);
                  return Expanded(
                    child: Tooltip(
                      message: '${pt.label}: ${pt.count}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: pt.count == 0 ? 3.0 : barHeight,
                              decoration: BoxDecoration(
                                color: pt.count == 0
                                    ? AppColors.border
                                    : barColor.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (points.length <= 10 ||
                                pt == points.first ||
                                pt == points.last)
                              Text(
                                pt.label.length >= 5
                                    ? pt.label.substring(pt.label.length - 5)
                                    : pt.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: AppColors.textMuted,
                                ),
                              )
                            else
                              const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItineraryDistributionCard() {
    final total = _data.totalItineraries;
    final segments = [
      (
        label: 'Công khai',
        count: _data.publicItineraries,
        color: const Color(0xFF7C3AED),
      ),
      (
        label: 'Riêng tư',
        count: _data.privateItineraries,
        color: const Color(0xFF2563EB),
      ),
      (label: 'Đã ẩn', count: _data.hiddenItineraries, color: AppColors.error),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 16,
                      color: Color(0xFF7C3AED),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phân bố lịch trình',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(AdminTab.itineraries),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Quản lý →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Chưa có lịch trình nào trong hệ thống.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: segments
                      .where((s) => s.count > 0)
                      .map(
                        (s) => Expanded(
                          flex: s.count,
                          child: Container(color: s.color),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...segments.map((s) {
              final pct = total > 0 ? (s.count * 100.0 / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${s.count} (${pct.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 16, color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đang hoạt động: ${_data.activeItineraries}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Tổng cộng: $total',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopPlacesCard() {
    final topPlaces = _data.topPlaces;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_outlined,
                      size: 16,
                      color: Color(0xFF15803D),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top địa điểm được đưa vào lịch trình',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(AdminTab.places),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Xem địa điểm →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (topPlaces.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu địa điểm nổi bật trong lịch trình.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topPlaces.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 10, color: AppColors.border),
              itemBuilder: (context, idx) {
                final place = topPlaces[idx];
                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: idx == 0
                            ? const Color(0xFFDCFCE7)
                            : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: idx == 0
                              ? const Color(0xFF15803D)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (place.areaName != null || place.category != null)
                            Text(
                              [
                                if (place.category != null) place.category!,
                                if (place.areaName != null) place.areaName!,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        '${place.itineraryCount} lịch trình',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentAuditLogsCard(List<AuditLogModel> logs) {
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
                const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Hoạt động quản trị gần đây',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(AdminTab.auditLogs),
                  child: const Text(
                    'Xem nhật ký →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Chưa có nhật ký hoạt động quản trị nào.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, idx) {
                final log = logs[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${log.actorUsername} • ${log.actionType} (${log.targetType} #${log.targetId})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AdminStatusBadge(status: log.resultStatus),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppColors.accentBorder,
                              width: 1,
                            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                    Icon(
                      Icons.check_circle_outline,
                      size: 24,
                      color: AppColors.success,
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: AppColors.warningBorder,
                            width: 1,
                          ),
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
                              report.reason.isNotEmpty
                                  ? report.reason
                                  : '(Không có lý do)',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        child: const Text(
                          'Xử lý',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textPrimary,
                          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                              post.content.isNotEmpty
                                  ? post.content
                                  : '(Đính kèm hình ảnh/lịch trình)',
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
}

class _MetricItemData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color tintColor;
  final Color borderColor;
  final VoidCallback onTap;
  final bool isAlert;

  _MetricItemData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.tintColor,
    required this.borderColor,
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

    final activeAccent = data.isAlert ? AppColors.error : data.accentColor;
    final baseBg = data.isAlert ? AppColors.errorLight : data.tintColor;
    final baseBorder = data.isAlert ? AppColors.errorBorder : data.borderColor;
    final valueColor = data.isAlert
        ? AppColors.accentDark
        : AppColors.textPrimary;
    final iconBgColor = activeAccent.withValues(alpha: isHovered ? 0.18 : 0.12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: data.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0.0,
            isHovered ? -2.0 : 0.0,
            0.0,
          ),
          decoration: BoxDecoration(
            color: isHovered ? baseBg.withValues(alpha: 0.95) : baseBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isHovered
                  ? activeAccent.withValues(alpha: 0.55)
                  : baseBorder,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Icon(data.icon, size: 16, color: activeAccent),
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
                            : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 13, color: activeAccent),
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
                  fontWeight: FontWeight.w500,
                  color: data.isAlert
                      ? AppColors.accentDark
                      : AppColors.textSecondary,
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
