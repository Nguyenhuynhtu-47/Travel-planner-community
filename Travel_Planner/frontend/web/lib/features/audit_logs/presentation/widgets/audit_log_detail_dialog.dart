import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../data/audit_log_repository.dart';
import '../../data/models/audit_log_model.dart';

/// Read-only modal for inspecting an Audit Log entry and its masked Before/After JSON snapshots.
class AuditLogDetailDialog extends StatefulWidget {
  final int logId;
  final String? token;
  final AuditLogRepository? repository;

  const AuditLogDetailDialog({
    super.key,
    required this.logId,
    this.token,
    this.repository,
  });

  @override
  State<AuditLogDetailDialog> createState() => _AuditLogDetailDialogState();
}

class _AuditLogDetailDialogState extends State<AuditLogDetailDialog> {
  late final AuditLogRepository _repository;
  AuditLogDetailModel? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AuditLogRepository();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _repository.getAuditLogById(
        widget.logId,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chi tiết Nhật ký Kiểm toán #${widget.logId} (Chỉ đọc)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 740,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _errorMessage != null
                ? Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Không thể tải chi tiết nhật ký: $_errorMessage',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Thử lại'),
                          onPressed: _loadDetail,
                        ),
                      ],
                    ),
                  )
                : _buildContent(_detail!),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildContent(AuditLogDetailModel detail) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildMetaChip('Hành động', detail.actionType),
                    _buildMetaChip(
                      'Đối tượng',
                      '${detail.targetType} #${detail.targetId}',
                    ),
                    AdminStatusBadge(status: detail.resultStatus),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  'Người thực hiện',
                  '${detail.actorUsername} (ID: ${detail.actorId})',
                ),
                _buildInfoRow('Thời gian', _formatDateTime(detail.createdAt)),
                _buildInfoRow('Địa chỉ IP', detail.ipAddress ?? '-'),
                _buildInfoRow('User-Agent', detail.userAgent ?? '-'),
                _buildInfoRow('Correlation ID', detail.correlationId ?? '-'),
                _buildInfoRow('Lý do / Ghi chú', detail.reason ?? '-'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dữ liệu nhạy cảm (mật khẩu, token, secret, PII) đã được che chắn (***MASKED***) và chỉ hiển thị ở chế độ chỉ đọc.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSnapshotBox(
                        'Snapshot Trước (Before)',
                        AuditLogDetailModel.formatJsonPretty(
                            detail.beforeDataJson),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildSnapshotBox(
                        'Snapshot Sau (After)',
                        AuditLogDetailModel.formatJsonPretty(
                            detail.afterDataJson),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSnapshotBox(
                    'Snapshot Trước (Before)',
                    AuditLogDetailModel.formatJsonPretty(
                        detail.beforeDataJson),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildSnapshotBox(
                    'Snapshot Sau (After)',
                    AuditLogDetailModel.formatJsonPretty(detail.afterDataJson),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotBox(String title, String prettyJson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 260),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              prettyJson,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
