import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/locations/data/models/place_model.dart';
import 'package:travel_planner_web/features/locations/data/place_repository.dart';

/// Modal dialog confirming soft deletion / status change of a canonical Place.
/// Clarifies status changes to HIDDEN without permanent record loss.
class HidePlaceDialog extends StatefulWidget {
  final PlaceModel place;
  final PlaceRepository repository;

  const HidePlaceDialog({
    super.key,
    required this.place,
    required this.repository,
  });

  static Future<bool?> show(
    BuildContext context, {
    required PlaceModel place,
    required PlaceRepository repository,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HidePlaceDialog(
        place: place,
        repository: repository,
      ),
    );
  }

  @override
  State<HidePlaceDialog> createState() => _HidePlaceDialogState();
}

class _HidePlaceDialogState extends State<HidePlaceDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleConfirm() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.place.isHidden) {
        // Reactivate: update status to ACTIVE
        final updateReq = UpdatePlaceRequest(
          name: widget.place.name,
          address: widget.place.address,
          description: widget.place.description,
          imageUrl: widget.place.imageUrl,
          latitude: widget.place.latitude ?? 0.0,
          longitude: widget.place.longitude ?? 0.0,
          category: widget.place.category,
          status: 'ACTIVE',
        );
        await widget.repository.updatePlace(widget.place.id, updateReq);
      } else {
        // Soft delete / hide
        await widget.repository.deletePlace(widget.place.id);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Không thể cập nhật trạng thái địa điểm: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHiding = widget.place.isActive;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHiding
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isHiding ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: isHiding ? AppColors.error : AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHiding ? 'Ẩn địa điểm chuẩn hóa' : 'Kích hoạt lại địa điểm',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHiding
                  ? 'Bạn có chắc chắn muốn ẩn địa điểm "${widget.place.name}" khỏi danh mục công khai?'
                  : 'Bạn có chắc chắn muốn kích hoạt lại địa điểm "${widget.place.name}" trong danh mục công khai?',
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHiding
                          ? 'Dữ liệu địa điểm và các hoạt động du lịch đã lưu vị trí này KHÔNG bị xóa. '
                            'Địa điểm sẽ tạm thời ẩn khỏi kết quả tìm kiếm danh mục công khai.'
                          : 'Địa điểm sẽ xuất hiện trở lại trong danh mục và kết quả tìm kiếm công khai.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isHiding ? AppColors.error : AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _handleConfirm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isHiding ? 'Ẩn địa điểm' : 'Kích hoạt'),
        ),
      ],
    );
  }
}
