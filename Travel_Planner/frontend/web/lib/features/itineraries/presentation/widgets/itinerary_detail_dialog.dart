import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../../users/presentation/widgets/user_avatar.dart';
import '../../data/itinerary_admin_repository.dart';
import '../../data/models/admin_itinerary_model.dart';

class ItineraryDetailDialog extends StatefulWidget {
  final int itineraryId;
  final String token;
  final ItineraryAdminRepository repository;
  final AdminItineraryDetailModel? initialDetail;

  const ItineraryDetailDialog({
    super.key,
    required this.itineraryId,
    required this.token,
    required this.repository,
    this.initialDetail,
  });

  static Future<void> show({
    required BuildContext context,
    required int itineraryId,
    required String token,
    required ItineraryAdminRepository repository,
    AdminItineraryDetailModel? initialDetail,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ItineraryDetailDialog(
        itineraryId: itineraryId,
        token: token,
        repository: repository,
        initialDetail: initialDetail,
      ),
    );
  }

  @override
  State<ItineraryDetailDialog> createState() => _ItineraryDetailDialogState();
}

class _ItineraryDetailDialogState extends State<ItineraryDetailDialog> {
  bool _loading = true;
  String? _error;
  AdminItineraryDetailModel? _detail;

  @override
  void initState() {
    super.initState();
    if (widget.initialDetail != null) {
      _detail = widget.initialDetail;
      _loading = false;
    } else {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.repository.getItineraryDetail(
        widget.itineraryId,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _detail = res;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.isNotEmpty
              ? e.message
              : 'Không thể tải chi tiết lịch trình.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải chi tiết lịch trình.';
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _formatBudget(double budget) {
    final rounded = budget.toStringAsFixed(0);
    return '$rounded đ';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return AdminDialog(
      title: 'Chi tiết lịch trình (Chỉ đọc)',
      titleBadge: detail != null
          ? AdminStatusBadge(status: detail.itinerary.status)
          : null,
      width: 720,
      content: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: _loadDetail,
                      child: const Text('Thử lại'),
                    ),
                  ],
                )
              : _buildDetailBody(detail!),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildDetailBody(AdminItineraryDetailModel detail) {
    final it = detail.itinerary;
    final creator = it.creator;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (detail.privateInspection) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Chế độ thanh tra lịch trình PRIVATE • Báo cáo #${detail.inspectedReportId ?? "-"} • Đã ghi nhận Strict Audit.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mã #${it.itineraryId} • ${it.location} • ${it.totalDays} ngày',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AdminStatusBadge(
              status: it.visibility == 'PRIVATE' ? 'WARNING' : 'INFO',
              customLabel:
                  it.visibility == 'PRIVATE' ? 'PRIVATE' : 'PUBLIC',
            ),
          ],
        ),
        if (creator != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              UserAvatar(
                avatarUrl: creator.avatar,
                displayName: creator.displayName,
                size: 32,
                fontSize: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Người tạo: ${creator.displayName} (@${creator.handle})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _statCell('Ngân sách', _formatBudget(it.budget)),
              _statCell('Lượt xem', '${it.viewCount}'),
              _statCell('Yêu thích', '${it.favoriteCount}'),
              _statCell('Tái sử dụng', '${it.reuseCount}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _infoRow('Chủ đề', it.theme?.isNotEmpty == true ? it.theme! : '-'),
        _infoRow('Ngày tạo', _formatDateTime(it.createdAt)),
        if (it.description != null && it.description!.trim().isNotEmpty)
          _infoRow('Mô tả', it.description!),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Lộ trình chi tiết (${detail.days.length} ngày):',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (detail.days.isEmpty)
          const Text(
            'Chưa có ngày lịch trình hoặc hoạt động nào.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          )
        else
          ...detail.days.map(_buildDaySection),
      ],
    );
  }

  Widget _buildDaySection(AdminItineraryDayModel day) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ngày ${day.dayNumber}${day.title != null && day.title!.isNotEmpty ? " — ${day.title}" : ""}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (day.activities.isEmpty)
            const Text(
              'Không có hoạt động trong ngày này.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            ...day.activities.map((act) {
              final timeText =
                  (act.startTime != null && act.endTime != null)
                      ? '${act.startTime} - ${act.endTime}'
                      : (act.startTime ?? '');
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (timeText.isNotEmpty ||
                              (act.locationName != null &&
                                  act.locationName!.isNotEmpty))
                            Text(
                              [
                                if (timeText.isNotEmpty) timeText,
                                if (act.locationName != null &&
                                    act.locationName!.isNotEmpty)
                                  act.locationName!,
                              ].join(' • '),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
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

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
