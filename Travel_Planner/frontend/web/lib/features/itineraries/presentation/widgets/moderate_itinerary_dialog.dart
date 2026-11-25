import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../../../shared/widgets/admin_status_badge.dart';
import '../../data/models/admin_itinerary_model.dart';

Future<bool?> showModerateItineraryDialog({
  required BuildContext context,
  required AdminItineraryModel itinerary,
  required Future<void> Function(String targetStatus, String reason) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ModerateItineraryDialog(
      itinerary: itinerary,
      onSubmit: onSubmit,
    ),
  );
}

class _ModerateItineraryDialog extends StatefulWidget {
  final AdminItineraryModel itinerary;
  final Future<void> Function(String targetStatus, String reason) onSubmit;

  const _ModerateItineraryDialog({
    required this.itinerary,
    required this.onSubmit,
  });

  @override
  State<_ModerateItineraryDialog> createState() =>
      _ModerateItineraryDialogState();
}

class _ModerateItineraryDialogState extends State<_ModerateItineraryDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm(String targetStatus) async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3 || reason.length > 255) {
      setState(() {
        _inlineError = 'Vui lòng nhập lý do từ 3 đến 255 ký tự.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _inlineError = null;
    });

    try {
      await widget.onSubmit(targetStatus, reason);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = e.message.isNotEmpty
              ? e.message
              : 'Không thể cập nhật trạng thái lịch trình.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;
    final isHide = itinerary.status != 'HIDDEN';
    final targetStatus = isHide ? 'HIDDEN' : 'ACTIVE';

    return AdminDialog(
      title: isHide ? 'Ẩn lịch trình vi phạm' : 'Khôi phục lịch trình',
      titleBadge: AdminStatusBadge(status: targetStatus),
      width: 490,
      onClose: _submitting ? null : () => Navigator.of(context).pop(false),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch trình #${itinerary.itineraryId}: ${itinerary.title}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
          if (itinerary.creator != null) ...[
            const SizedBox(height: 2),
            Text(
              'Người tạo: ${itinerary.creator!.displayName} (@${itinerary.creator!.handle})',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isHide ? AppColors.warningLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color:
                    isHide ? AppColors.warningBorder : AppColors.successBorder,
              ),
            ),
            child: Text(
              isHide
                  ? 'Ẩn lịch trình sẽ gỡ chuyến đi này khỏi danh sách công khai trên toàn hệ thống, đồng thời giữ nguyên dữ liệu cá nhân của tác giả và ghi Strict Audit.'
                  : 'Khôi phục sẽ đưa lịch trình trở lại trạng thái Hoạt động và ghi nhận Strict Audit.',
              style: TextStyle(
                fontSize: 12.5,
                color: isHide ? AppColors.warning : AppColors.success,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reasonController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 255,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: isHide ? 'Lý do ẩn lịch trình *' : 'Lý do khôi phục *',
              hintText: isHide
                  ? 'VD: Nội dung chứa quảng cáo spam hoặc thông tin sai lệch...'
                  : 'VD: Đã xác minh lịch trình hợp lệ sau khi chỉnh sửa...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _inlineError!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : () => _handleConfirm(targetStatus),
          style: ElevatedButton.styleFrom(
            backgroundColor: isHide ? AppColors.warning : AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isHide ? 'Xác nhận ẩn' : 'Xác nhận khôi phục'),
        ),
      ],
    );
  }
}
