import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_data_table.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../../shared/widgets/hover_movement.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/admin_post_report_model.dart';
import '../../data/moderation_repository.dart';

/// Professional Enterprise Reports screen for Travel Planner Web Admin.
/// Aligned with docs/plan/admin-design-system.md (Minimalism & Swiss Style).
class AdminReportsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ModerationRepository? repository;
  final bool embedded;

  const AdminReportsScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late final ModerationRepository _repository;
  bool _loading = false;
  List<AdminPostReportModel> _reports = [];
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;
  String _statusFilter = 'PENDING';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _token;
  String? _errorMessage;

  bool get isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ModerationRepository();
    _token = widget.authNotifier.token;
    if (isAdmin) {
      _loadReports();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiConstants.baseUrl}$trimmed';
    }
    return '${ApiConstants.baseUrl}/$trimmed';
  }

  String _parseErrorMessage(dynamic error, String fallback) {
    if (error is ApiException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    return fallback;
  }

  Future<void> _loadReports() async {
    if (_token == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
      final res = await _repository.getReportsPaged(
        status: statusParam,
        page: _page,
        size: _pageSize,
        token: _token!,
      );
      if (mounted) {
        setState(() {
          _reports = res.content;
          _totalPages = res.totalPages;
          _totalElements = res.totalElements;
          _page = res.page;
        });
      }
    } catch (e) {
      final msg = _parseErrorMessage(e, 'Không thể tải danh sách báo cáo');
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPageChanged(int newPage) {
    if (newPage != _page && newPage >= 0) {
      setState(() => _page = newPage);
      _loadReports();
    }
  }

  Future<void> _resolveReport(int reportId, String resolution) async {
    if (_token == null) return;
    try {
      await _repository.resolveReport(
        reportId,
        status: resolution,
        token: _token!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolution == 'RESOLVED'
                ? 'Đã xử lý vi phạm thành công.'
                : 'Đã bỏ qua báo cáo.'),
          ),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseErrorMessage(e, 'Không thể cập nhật báo cáo')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReportDetailDialog(AdminPostReportModel report) {
    AdminDialog.show<void>(
      context: context,
      width: 580,
      title: 'Chi tiết báo cáo #${report.reportId}',
      titleBadge: AdminStatusBadge(status: report.status),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reporter Info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accentLight,
                backgroundImage: report.reporter?.avatar != null &&
                        report.reporter!.avatar!.isNotEmpty
                    ? NetworkImage(_resolveImageUrl(report.reporter!.avatar!))
                    : null,
                child: report.reporter?.avatar == null ||
                        report.reporter!.avatar!.isEmpty
                    ? Text(
                        report.reporter?.displayName.isNotEmpty == true
                            ? report.reporter!.displayName[0].toUpperCase()
                            : 'R',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentDark,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reporter?.displayName ?? 'Ẩn danh',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    if (report.reporter?.handle != null)
                      Text(
                        '@${report.reporter!.handle}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Report Detail key-value section
          _buildDetailRow('Mục tiêu bài viết:', 'Post #${report.postId}'),
          _buildDetailRow('Lý do báo cáo:', report.reason),
          _buildDetailRow('Mô tả chi tiết:', report.details ?? 'Không có chi tiết thêm'),
          _buildDetailRow('Trạng thái hiện tại:', report.status),
          _buildDetailRow(
            'Ngày gửi báo cáo:',
            '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year} ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          if (report.resolvedAt != null)
            _buildDetailRow(
              'Ngày giải quyết:',
              '${report.resolvedAt!.day}/${report.resolvedAt!.month}/${report.resolvedAt!.year} ${report.resolvedAt!.hour}:${report.resolvedAt!.minute.toString().padLeft(2, '0')}',
            ),
        ],
      ),
      actions: [
        if (report.status == 'PENDING') ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _resolveReport(report.reportId, 'RESOLVED');
            },
            child: const Text('Xử lý vi phạm'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderStrong),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _resolveReport(report.reportId, 'DISMISSED');
            },
            child: const Text('Bỏ qua'),
          ),
        ],
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý báo cáo')),
        body: const Center(
          child: Text(
            'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.',
            style: TextStyle(color: AppColors.error, fontSize: 16),
          ),
        ),
      );
    }

    final filteredReports = _reports.where((report) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchId = report.reportId.toString().contains(q);
      final matchPostId = report.postId.toString().contains(q);
      final matchReason = report.reason.toLowerCase().contains(q);
      final matchDetails = report.details?.toLowerCase().contains(q) ?? false;
      final matchReporter =
          report.reporter?.displayName.toLowerCase().contains(q) ?? false;
      return matchId || matchPostId || matchReason || matchDetails || matchReporter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Quản lý báo cáo vi phạm'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Standalone Enterprise Page Header
          AdminPageHeader(
            title: 'Quản lý báo cáo vi phạm',
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(
                  'Tổng: $_totalElements báo cáo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Standard Admin Toolbar (Filters & Search)
          AdminToolbar(
            filters: [
              // Search input
              SizedBox(
                width: 260,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm ID, Post ID, lý do, người báo...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            splashRadius: 14,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: const BorderSide(color: AppColors.primaryAccessible),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),

              // Status Dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trạng thái: ',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'PENDING', child: Text('Chờ xử lý (PENDING)')),
                          DropdownMenuItem(value: 'RESOLVED', child: Text('Đã xử lý (RESOLVED)')),
                          DropdownMenuItem(value: 'DISMISSED', child: Text('Đã bỏ qua (DISMISSED)')),
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _statusFilter) {
                            setState(() {
                              _statusFilter = val;
                              _page = 0;
                            });
                            _loadReports();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                onPressed: _loadReports,
              ),
            ],
          ),

          // Error Banner if network/server failed
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.errorBorder, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadReports,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Thử lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Data Table Workspace using AdminDataTable
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AdminDataTable(
                isLoading: _loading,
                columnSpacing: 16,
                emptyMessage: _searchQuery.isNotEmpty
                    ? 'Không tìm thấy báo cáo nào khớp với từ khóa "$_searchQuery".'
                    : 'Không có báo cáo nào.',
                currentPage: _page,
                totalPages: _totalPages,
                totalElements: _totalElements,
                pageSize: _pageSize,
                onPageChanged: _onPageChanged,
                columns: [
                  AdminDataColumn.text('MÃ BÁO CÁO', numeric: true),
                  AdminDataColumn.text('MÃ BÀI VIẾT', numeric: true),
                  AdminDataColumn.text('NGƯỜI BÁO CÁO'),
                  AdminDataColumn.text('LÝ DO'),
                  AdminDataColumn.text('CHI TIẾT'),
                  AdminDataColumn.text('TRẠNG THÁI'),
                  AdminDataColumn.text('NGÀY BÁO CÁO'),
                  AdminDataColumn.text('THAO TÁC'),
                ],
                rows: filteredReports.map((report) {
                  return AdminDataRow(
                    onTap: () => _showReportDetailDialog(report),
                    cells: [
                      Text(
                        '#${report.reportId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      Text(
                        '#${report.postId}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Text(
                        report.reporter?.displayName ?? 'Ẩn danh',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        report.reason,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          report.details ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      AdminStatusBadge(status: report.status),
                      Text(
                        '${report.createdAt.day.toString().padLeft(2, '0')}/${report.createdAt.month.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HoverMovement.button(
                            child: Tooltip(
                              message: 'Xem chi tiết báo cáo vi phạm',
                              child: TextButton(
                                onPressed: () => _showReportDetailDialog(report),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: AppColors.textSecondary,
                                ),
                                child: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                          if (report.status == 'PENDING') ...[
                            HoverMovement.button(
                              child: Tooltip(
                                message: 'Xác nhận vi phạm và giải quyết báo cáo',
                                child: TextButton(
                                  onPressed: () => _resolveReport(report.reportId, 'RESOLVED'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Xử lý vi phạm',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            HoverMovement.button(
                              child: Tooltip(
                                message: 'Từ chối hoặc bỏ qua báo cáo này',
                                child: TextButton(
                                  onPressed: () => _resolveReport(report.reportId, 'DISMISSED'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.warning,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Bỏ qua',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
