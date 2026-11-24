import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/network/api_exception.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/locations/data/models/place_model.dart';
import 'package:travel_planner_web/features/locations/data/place_repository.dart';
import 'package:travel_planner_web/shared/widgets/admin_dialog.dart';
import 'package:travel_planner_web/shared/widgets/admin_status_badge.dart';

/// Modal dialog confirming soft deletion / status change of a canonical Place.
/// Clarifies status changes to HIDDEN without permanent record loss.
/// Aligned with docs/plan/admin-design-system.md (Minimalism & Swiss Style).
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

    return AdminDialog(
      width: 480,
      title: isHiding ? 'Ẩn địa điểm chuẩn hóa' : 'Kích hoạt lại địa điểm',
      titleBadge: AdminStatusBadge(status: isHiding ? 'ACTIVE' : 'HIDDEN'),
      onClose: _isSubmitting ? null : () => Navigator.of(context).pop(false),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHiding
                ? 'Bạn có chắc chắn muốn ẩn địa điểm "${widget.place.name}" khỏi danh mục công khai?'
                : 'Bạn có chắc chắn muốn kích hoạt lại địa điểm "${widget.place.name}" trong danh mục công khai?',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isHiding
                        ? 'Dữ liệu địa điểm và các hoạt động du lịch đã lưu vị trí này KHÔNG bị xóa. '
                          'Địa điểm sẽ tạm thời ẩn khỏi kết quả tìm kiếm danh mục công khai.'
                        : 'Địa điểm sẽ xuất hiện trở lại trong danh mục và kết quả tìm kiếm công khai.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
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
                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.borderStrong),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy', style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isHiding ? AppColors.warning : AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          onPressed: _isSubmitting ? null : _handleConfirm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isHiding ? 'Ẩn địa điểm' : 'Kích hoạt',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
