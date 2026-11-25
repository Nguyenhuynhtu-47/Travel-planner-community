import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_data_table.dart';
import '../../../../shared/widgets/admin_page_header.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/audit_log_repository.dart';
import '../../data/models/audit_log_model.dart';
import '../widgets/audit_log_detail_dialog.dart';

/// Phase 5: Read-only Audit Logs Explorer Screen (ROLE_ADMIN only).
class AdminAuditLogsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final AuditLogRepository? repository;
  final bool embedded;

  const AdminAuditLogsScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.embedded = false,
  });

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  late final AuditLogRepository _repository;

  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _actorController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  String _actionTypeFilter = 'ALL';
  String _targetTypeFilter = 'ALL';
  String _resultStatusFilter = 'ALL';

  List<AuditLogModel> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _page = 0;
  final int _pageSize = 20;
  int _totalPages = 0;
  int _totalElements = 0;

  static const List<String> _actionTypes = [
    'ALL',
    'USER_BAN',
    'USER_UNBAN',
    'USER_ROLE_CHANGE',
    'USER_SESSIONS_REVOKE',
    'ITINERARY_MODERATE',
    'ITINERARY_PRIVATE_INSPECT',
    'POST_MODERATE',
    'POST_PURGE',
    'REPORT_RESOLVE',
    'PLACE_ADMIN_AREA_LINK',
    'PLACE_ADMIN_AREA_BATCH_RESOLVE',
    'SETTING_UPDATE',
    'MAINTENANCE_TOGGLE',
    'AUDIT_EXPORT',
    'AUDIT_EXPORT_DELIVERY_FAILED',
  ];

  static const List<String> _targetTypes = [
    'ALL',
    'USER',
    'ITINERARY',
    'POST',
    'POST_REPORT',
    'PLACE',
    'MEDIA_ASSET',
    'SYSTEM_SETTING',
    'AUDIT_LOG',
    'SYSTEM',
  ];

  static const List<String> _resultStatuses = [
    'ALL',
    'SUCCESS',
    'FAILED',
    'DELIVERY_FAILED',
  ];

  bool get _isAdmin =>
      widget.authNotifier.currentUser?['role']?.toString().toUpperCase() ==
      'ADMIN';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AuditLogRepository();
    if (_isAdmin) {
      _loadLogs();
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _actorController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _page = targetPage;
    });

    try {
      final res = await _repository.getAuditLogsPaged(
        keyword: _keywordController.text,
        actorUsername: _actorController.text,
        actionType: _actionTypeFilter,
        targetType: _targetTypeFilter,
        resultStatus: _resultStatusFilter,
        fromDate: _fromDateController.text,
        toDate: _toDateController.text,
        page: targetPage,
        size: _pageSize,
        token: widget.authNotifier.token,
      );
      if (!mounted) return;
      setState(() {
        _logs = res.content;
        _totalPages = res.totalPages;
        _totalElements = res.totalElements;
        _page = res.page;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    _keywordController.clear();
    _actorController.clear();
    _fromDateController.clear();
    _toDateController.clear();
    setState(() {
      _actionTypeFilter = 'ALL';
      _targetTypeFilter = 'ALL';
      _resultStatusFilter = 'ALL';
    });
    _loadLogs(page: 0);
  }

  void _openDetailDialog(AuditLogModel log) {
    showDialog(
      context: context,
      builder: (_) => AuditLogDetailDialog(
        logId: log.logId,
        token: widget.authNotifier.token,
        repository: _repository,
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 52, color: AppColors.error),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Truy cập bị từ chối',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Bạn cần quyền Quản trị viên (ADMIN) để tra cứu nhật ký hoạt động hệ thống.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Nhật ký hoạt động',
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Làm mới'),
                onPressed: _isLoading ? null : () => _loadLogs(),
              ),
            ],
          ),
          _buildFilterBar(),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.error),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Thử lại'),
                    onPressed: () => _loadLogs(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 1080.0;
                  final minWidth =
                      availableWidth > 960.0 ? availableWidth : 960.0;

                  return AdminDataTable(
                    isLoading: _isLoading,
                    minWidth: minWidth,
                    columnSpacing: 14,
                    horizontalMargin: 14,
                    dataRowHeight: AppHeights.tableRowComfortable,
                    emptyMessage: 'Không tìm thấy bản ghi nhật ký kiểm toán nào.',
                    currentPage: _page,
                    totalPages: _totalPages,
                    totalElements: _totalElements,
                    pageSize: _pageSize,
                    onPageChanged: (newPage) => _loadLogs(page: newPage),
                    columns: [
                      AdminDataColumn.text('THỜI GIAN'),
                      AdminDataColumn.text('NGƯỜI THỰC HIỆN'),
                      AdminDataColumn.text('HÀNH ĐỘNG'),
                      AdminDataColumn.text('ĐỐI TƯỢNG TÁC ĐỘNG'),
                      AdminDataColumn.text('KẾT QUẢ'),
                      AdminDataColumn.text('THAO TÁC'),
                    ],
                    rows: _logs.map((log) {
                      return AdminDataRow(
                        onTap: () => _openDetailDialog(log),
                        cells: [
                          Text(
                            _formatDateTime(log.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            log.actorUsername,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              log.actionType,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${log.targetType} #${log.targetId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          AdminStatusBadge(status: log.resultStatus),
                          TextButton.icon(
                            icon: const Icon(Icons.visibility_outlined,
                                size: 15),
                            label: const Text(
                              'Chi tiết',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _openDetailDialog(log),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 210,
            child: TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                hintText: 'Từ khóa / Target ID / Lý do...',
                prefixIcon: Icon(Icons.search, size: 17),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadLogs(page: 0),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: _actorController,
              decoration: const InputDecoration(
                hintText: 'Người thực hiện...',
                prefixIcon: Icon(Icons.person_outline, size: 17),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadLogs(page: 0),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: _actionTypeFilter,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Hành động',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _actionTypes
                  .map((a) => DropdownMenuItem(
                        value: a,
                        child: Text(
                          a == 'ALL' ? 'Tất cả hành động' : a,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _actionTypeFilter = val);
                _loadLogs(page: 0);
              },
            ),
          ),
          SizedBox(
            width: 165,
            child: DropdownButtonFormField<String>(
              initialValue: _targetTypeFilter,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Đối tượng',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _targetTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == 'ALL' ? 'Tất cả đối tượng' : t,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _targetTypeFilter = val);
                _loadLogs(page: 0);
              },
            ),
          ),
          SizedBox(
            width: 155,
            child: DropdownButtonFormField<String>(
              initialValue: _resultStatusFilter,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Kết quả',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _resultStatuses
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s == 'ALL' ? 'Tất cả kết quả' : s,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _resultStatusFilter = val);
                _loadLogs(page: 0);
              },
            ),
          ),
          SizedBox(
            width: 135,
            child: TextField(
              controller: _fromDateController,
              decoration: const InputDecoration(
                labelText: 'Từ ngày',
                hintText: 'YYYY-MM-DD',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadLogs(page: 0),
            ),
          ),
          SizedBox(
            width: 135,
            child: TextField(
              controller: _toDateController,
              decoration: const InputDecoration(
                labelText: 'Đến ngày',
                hintText: 'YYYY-MM-DD',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadLogs(page: 0),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.filter_alt_outlined, size: 16),
            label: const Text('Lọc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: _isLoading ? null : () => _loadLogs(page: 0),
          ),
          TextButton(
            onPressed: _isLoading ? null : _resetFilters,
            child: const Text('Xóa lọc'),
          ),
        ],
      ),
    );
  }
}
