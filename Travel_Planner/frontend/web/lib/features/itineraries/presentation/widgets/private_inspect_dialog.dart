import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_dialog.dart';
import '../../data/models/admin_itinerary_model.dart';

Future<AdminItineraryDetailModel?> showPrivateInspectDialog({
  required BuildContext context,
  required Future<AdminItineraryDetailModel> Function({
    required int itineraryId,
    required int reportId,
    required String inspectionReason,
  }) onInspect,
}) {
  return showDialog<AdminItineraryDetailModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PrivateInspectDialog(onInspect: onInspect),
  );
}

class _PrivateInspectDialog extends StatefulWidget {
  final Future<AdminItineraryDetailModel> Function({
    required int itineraryId,
    required int reportId,
    required String inspectionReason,
  }) onInspect;

  const _PrivateInspectDialog({required this.onInspect});

  @override
  State<_PrivateInspectDialog> createState() => _PrivateInspectDialogState();
}

class _PrivateInspectDialogState extends State<_PrivateInspectDialog> {
  final TextEditingController _itineraryIdController = TextEditingController();
  final TextEditingController _reportIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _itineraryIdController.dispose();
    _reportIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleInspect() async {
    final itineraryId = int.tryParse(_itineraryIdController.text.trim());
    final reportId = int.tryParse(_reportIdController.text.trim());
    final reason = _reasonController.text.trim();

    if (itineraryId == null || itineraryId <= 0) {
      setState(() => _inlineError = 'Vui lòng nhập mã lịch trình hợp lệ.');
      return;
    }
    if (reportId == null || reportId <= 0) {
      setState(
          () => _inlineError = 'Vui lòng nhập mã báo cáo PENDING hợp lệ.');
      return;
    }
    if (reason.length < 10 || reason.length > 255) {
      setState(() => _inlineError =
          'Lý do thanh tra lịch trình PRIVATE phải từ 10 đến 255 ký tự.');
      return;
    }

    setState(() {
      _submitting = true;
      _inlineError = null;
    });

    try {
      final detail = await widget.onInspect(
        itineraryId: itineraryId,
        reportId: reportId,
        inspectionReason: reason,
      );
      if (mounted) {
        Navigator.of(context).pop(detail);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = e.message.isNotEmpty
              ? e.message
              : 'Không thể thanh tra lịch trình PRIVATE.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _inlineError = 'Đã có lỗi xảy ra khi kiểm tra lịch trình PRIVATE.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      title: 'Thanh tra lịch trình PRIVATE',
      width: 500,
      onClose: _submitting ? null : () => Navigator.of(context).pop(null),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.infoBorder),
            ),
            child: const Text(
              'Lịch trình PRIVATE chỉ được mở xem ở chế độ chỉ đọc khi có mã báo cáo đang chờ xử lý (PENDING) liên kết trực tiếp. Mọi lượt mở xem sẽ được ghi nhận Strict Audit bắt buộc.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.info,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itineraryIdController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Mã lịch trình *',
                    hintText: 'VD: 105',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _reportIdController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Mã báo cáo (Report ID) *',
                    hintText: 'VD: 42',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reasonController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 255,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Lý do thanh tra (tối thiểu 10 ký tự) *',
              hintText:
                  'VD: Kiểm tra lịch trình PRIVATE được gắn kèm báo cáo spam #42...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
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
          onPressed: _submitting ? null : () => Navigator.of(context).pop(null),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _handleInspect,
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.policy_outlined, size: 16),
          label: const Text('Mở xem chỉ đọc'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }
}
