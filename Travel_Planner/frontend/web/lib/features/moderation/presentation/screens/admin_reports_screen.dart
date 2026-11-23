import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../../shared/widgets/admin_toolbar.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/admin_post_report_model.dart';
import '../../data/moderation_repository.dart';

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
  String _statusFilter = 'PENDING';
  String? _token;

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

  String _errorMessage(dynamic error, String fallback) {
    if (error is ApiException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    return fallback;
  }

  Future<void> _loadReports() async {
    if (_token == null) return;
    setState(() => _loading = true);
    try {
      final statusParam = _statusFilter == 'ALL' ? null : _statusFilter;
      final res = await _repository.getReports(
        status: statusParam,
        token: _token!,
      );
      if (mounted) setState(() => _reports = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e, 'Không thể tải danh sách báo cáo')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
            content: Text(_errorMessage(e, 'Không thể cập nhật báo cáo')),
          ),
        );
      }
    }
  }

  void _showReportDetailDialog(AdminPostReportModel report) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('Chi tiết báo cáo #${report.reportId}'),
            const Spacer(),
            AdminStatusBadge(status: report.status),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reporter Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      backgroundImage: report.reporter?.avatar != null &&
                              report.reporter!.avatar!.isNotEmpty
                          ? NetworkImage(
                              _resolveImageUrl(report.reporter!.avatar!))
                          : null,
                      child: report.reporter?.avatar == null ||
                              report.reporter!.avatar!.isEmpty
                          ? const Icon(Icons.person, color: Colors.red)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.reporter?.displayName ?? 'Ẩn danh',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (report.reporter?.handle != null)
                            Text(
                              '@${report.reporter!.handle}',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Report Details
                _buildDetailRow('Mục tiêu bài viết:', 'Post #${report.postId}'),
                _buildDetailRow('Lý do báo cáo:', report.reason),
                _buildDetailRow('Mô tả chi tiết:', report.details ?? 'Không có chi tiết thêm'),
                _buildDetailRow('Trạng thái hiện tại:', report.status),
                _buildDetailRow('Ngày gửi báo cáo:',
                    '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year} ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}'),
              ],
            ),
          ),
        ),
        actions: [
          if (report.status == 'PENDING') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(ctx);
                _resolveReport(report.reportId, 'RESOLVED');
              },
              child: const Text('Xử lý vi phạm',
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              onPressed: () {
                Navigator.pop(ctx);
                _resolveReport(report.reportId, 'DISMISSED');
              },
              child: const Text('Bỏ qua',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87)),
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
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

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
          // Standalone Page Header
          const AdminPageHeader(
            title: 'Quản lý báo cáo vi phạm',
            subtitle:
                'Xử lý, phân giải và rà soát các báo cáo vi phạm tiêu chuẩn từ cộng đồng người dùng.',
          ),

          // Standard Admin Toolbar
          AdminToolbar(
            filters: [
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
                      borderRadius: BorderRadius.circular(4),
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
                          if (val != null) {
                            setState(() => _statusFilter = val);
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
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _loadReports,
              ),
            ],
          ),

          // Data Table Workspace
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _reports.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có báo cáo nào.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 24,
                              horizontalMargin: 16,
                              headingRowHeight: 38,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 52,
                              headingRowColor: WidgetStateProperty.all(AppColors.surfaceSoft),
                              headingTextStyle: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                                letterSpacing: 0.3,
                              ),
                              columns: const [
                                DataColumn(label: Text('REPORT ID')),
                                DataColumn(label: Text('POST ID')),
                                DataColumn(label: Text('NGƯỜI BÁO CÁO')),
                                DataColumn(label: Text('LÝ DO')),
                                DataColumn(label: Text('CHI TIẾT')),
                                DataColumn(label: Text('TRẠNG THÁI')),
                                DataColumn(label: Text('NGÀY BÁO CÁO')),
                                DataColumn(label: Text('THAO TÁC')),
                              ],
                              rows: _reports.map((report) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text('#${report.reportId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                      onTap: () => _showReportDetailDialog(report),
                                    ),
                                    DataCell(
                                      Text('#${report.postId}', style: const TextStyle(fontSize: 12.5)),
                                      onTap: () => _showReportDetailDialog(report),
                                    ),
                                    DataCell(
                                      Text(report.reporter?.displayName ?? 'Ẩn danh', style: const TextStyle(fontSize: 12.5)),
                                      onTap: () => _showReportDetailDialog(report),
                                    ),
                                    DataCell(
                                      Text(report.reason, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                      onTap: () => _showReportDetailDialog(report),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          report.details ?? '-',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      onTap: () => _showReportDetailDialog(report),
                                    ),
                                    DataCell(AdminStatusBadge(status: report.status)),
                                    DataCell(Text(
                                      '${report.createdAt.day.toString().padLeft(2, '0')}/${report.createdAt.month.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    )),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () => _showReportDetailDialog(report),
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            child: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                                          ),
                                          if (report.status == 'PENDING') ...[
                                            TextButton(
                                              onPressed: () => _resolveReport(report.reportId, 'RESOLVED'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.green.shade800,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              child: const Text('Xử lý vi phạm', style: TextStyle(fontSize: 12)),
                                            ),
                                            TextButton(
                                              onPressed: () => _resolveReport(report.reportId, 'DISMISSED'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppColors.textSecondary,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              child: const Text('Bỏ qua', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
