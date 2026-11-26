import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/activity_detail.dart';
import 'navigation_launcher_helper.dart';

class ActivityTimelineItem extends StatelessWidget {
  final ActivityDetail activity;
  final int sequenceNumber;
  final Color dayColor;
  final Color dayLightColor;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onComments;
  final VoidCallback? onTap;
  final VoidCallback? onSavePlace;
  final VoidCallback? onDirections;

  const ActivityTimelineItem({
    super.key,
    required this.activity,
    this.sequenceNumber = 1,
    this.dayColor = AppColors.primary,
    this.dayLightColor = AppColors.primaryLight,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
    this.onComments,
    this.onTap,
    this.onSavePlace,
    this.onDirections,
  });

  String _formatCost(double cost) {
    if (cost <= 0) return 'Miễn phí';
    final formatted = cost.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }

  String? _formatActivityType(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return switch (raw.trim().toUpperCase()) {
      'SIGHTSEEING' || 'ATTRACTION' => 'Điểm tham quan',
      'DINING' || 'FOOD' || 'RESTAURANT' => 'Ẩm thực',
      'ACCOMMODATION' || 'HOTEL' => 'Lưu trú',
      'TRANSPORT' || 'TRANSPORTATION' => 'Di chuyển',
      'SHOPPING' => 'Mua sắm',
      'ENTERTAINMENT' => 'Giải trí',
      'OTHER' => 'Khác',
      _ => raw.trim(),
    };
  }

  String? _secondaryLocationLine() {
    final location = activity.effectiveLocationName?.trim();
    final address = activity.effectiveAddress?.trim();
    final description = activity.description?.trim();

    if (location != null &&
        location.isNotEmpty &&
        location.toLowerCase() != activity.name.trim().toLowerCase()) {
      if (address != null &&
          address.isNotEmpty &&
          address.toLowerCase() != location.toLowerCase()) {
        return '$location • $address';
      }
      return location;
    }
    if (address != null && address.isNotEmpty) return address;
    if (description != null && description.isNotEmpty) return description;
    if (activity.effectiveLatitude != null &&
        activity.effectiveLongitude != null) {
      return '${activity.effectiveLatitude!.toStringAsFixed(4)}, ${activity.effectiveLongitude!.toStringAsFixed(4)}';
    }
    return null;
  }

  Future<void> _openOptionsSheet(BuildContext context) async {
    final hasDirections = onDirections != null || activity.hasCoordinates;
    final options = <AppBottomSheetOption<String>>[
      if (onTap != null)
        const AppBottomSheetOption(
          value: 'view',
          icon: Icons.visibility_outlined,
          label: 'Xem chi tiết địa điểm',
        ),
      if (onSavePlace != null)
        const AppBottomSheetOption(
          value: 'save_place',
          icon: Icons.bookmark_add_outlined,
          label: 'Lưu địa điểm',
        ),
      if (hasDirections)
        const AppBottomSheetOption(
          value: 'directions',
          icon: Icons.directions_outlined,
          label: 'Chỉ đường trên bản đồ',
        ),
      if (onEdit != null)
        const AppBottomSheetOption(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: 'Chỉnh sửa hoạt động',
        ),
      if (onDelete != null)
        const AppBottomSheetOption(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Xóa hoạt động',
          isDestructive: true,
        ),
    ];

    if (options.isEmpty) return;

    final selected = await AppBottomSheet.showOptions<String>(
      context,
      title: activity.name,
      options: options,
    );

    if (selected == null || !context.mounted) return;
    switch (selected) {
      case 'view':
        onTap?.call();
      case 'save_place':
        onSavePlace?.call();
      case 'directions':
        if (onDirections != null) {
          onDirections!();
        } else if (activity.hasCoordinates) {
          await NavigationLauncherHelper.launchNavigation(
            context: context,
            stops: [
              NavigationStop(
                point: LatLng(
                  activity.effectiveLatitude!,
                  activity.effectiveLongitude!,
                ),
                label: activity.navigationDisplayName,
              ),
            ],
          );
        }
      case 'edit':
        onEdit?.call();
      case 'delete':
        onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted = activity.timeRangeFormatted;
    final activityImageUrl = activity.effectiveImageUrl?.trim();
    final hasImage = activityImageUrl != null && activityImageUrl.isNotEmpty;
    final hasCatalogRef =
        activity.place != null || activity.destination != null;
    final secondaryLine = _secondaryLocationLine();
    final categoryLabel = _formatActivityType(activity.activityType);
    final hasOptions =
        onTap != null ||
        onSavePlace != null ||
        onDirections != null ||
        activity.hasCoordinates ||
        onEdit != null ||
        onDelete != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEBEBEF)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Sequence badge + Activity info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: Day-colored sequence badge + bold title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: activity.visited
                                  ? const Color(0xFF6E6E73)
                                  : dayColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: activity.visited
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '$sequenceNumber',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activity.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1E1E),
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Line 2: Time range + Estimated cost + Visited pill
                      if (timeFormatted != null ||
                          (activity.estimatedCost != null &&
                              activity.estimatedCost! > 0) ||
                          activity.visited) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (timeFormatted != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Color(0xFF6E6E73),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    timeFormatted,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E1E1E),
                                    ),
                                  ),
                                ],
                              ),
                            if (activity.estimatedCost != null &&
                                activity.estimatedCost! > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatCost(activity.estimatedCost!),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            if (activity.visited)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      size: 11,
                                      color: Color(0xFF10B981),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Đã ghé thăm',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],

                      // Line 3: Location/description + Category tag + optional comments
                      if (secondaryLine != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          secondaryLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                      ],

                      if (categoryLabel != null || onComments != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (categoryLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: dayLightColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  categoryLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: dayColor,
                                  ),
                                ),
                              ),
                            if (onComments != null)
                              BounceTap(
                                child: InkWell(
                                  onTap: onComments,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.mode_comment_outlined,
                                          size: 13,
                                          color: Color(0xFF6E6E73),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${activity.commentCount}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6E6E73),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Right: 70x70 rounded thumbnail + compact options button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEFEFF4)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasImage
                          ? Image.network(
                              activityImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _buildThumbnailPlaceholder(hasCatalogRef),
                            )
                          : _buildThumbnailPlaceholder(hasCatalogRef),
                    ),
                    if (hasOptions) ...[
                      const SizedBox(width: 2),
                      BounceTap.icon(
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => _openOptionsSheet(context),
                            borderRadius: BorderRadius.circular(8),
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: Icon(
                                Icons.more_horiz,
                                size: 19,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(bool hasCatalogRef) {
    return Container(
      color: dayLightColor,
      alignment: Alignment.center,
      child: Icon(
        hasCatalogRef ? Icons.place_rounded : Icons.pin_drop_rounded,
        size: 24,
        color: dayColor,
      ),
    );
  }
}
