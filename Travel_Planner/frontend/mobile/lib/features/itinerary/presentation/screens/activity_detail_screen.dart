import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_map_view.dart';
import '../../data/models/activity_detail.dart';
import '../widgets/navigation_launcher_helper.dart';

/// Read-only screen for viewing complete details of an itinerary activity.
///
/// Follows the Travel Planner design system (DESIGN.md & docs/ai/04-ui-design-system.md):
/// pure white canvas, modest typographic weight, clear visual hierarchy,
/// no mutation actions, and robust fallbacks for missing/empty fields.
class ActivityDetailScreen extends StatelessWidget {
  final ActivityDetail? activity;
  final int? dayNumber;
  final String? dayTitle;
  final String? itineraryTitle;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    this.dayNumber,
    this.dayTitle,
    this.itineraryTitle,
  });

  /// Formats cost as Vietnamese Dong or 'Miễn phí'.
  static String formatCost(double cost) {
    if (cost <= 0) return 'Miễn phí';
    final formatted = cost.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }

  /// Calculates human-readable duration from startTime and endTime strings.
  ///
  /// Examples:
  /// - '08:00', '10:30' -> '2 giờ 30 phút'
  /// - '09:00', '10:00' -> '1 giờ'
  /// - '14:15', '14:45' -> '30 phút'
  /// - Returns `null` if times cannot be parsed or diff is 0.
  static String? calculateDuration(String? start, String? end) {
    if (start == null || end == null) return null;
    final startMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(start.trim());
    final endMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(end.trim());
    if (startMatch == null || endMatch == null) return null;

    final startHour = int.tryParse(startMatch.group(1)!);
    final startMin = int.tryParse(startMatch.group(2)!);
    final endHour = int.tryParse(endMatch.group(1)!);
    final endMin = int.tryParse(endMatch.group(2)!);

    if (startHour == null || startMin == null || endHour == null || endMin == null) {
      return null;
    }

    final startTotal = startHour * 60 + startMin;
    var endTotal = endHour * 60 + endMin;

    if (endTotal < startTotal) {
      endTotal += 24 * 60; // crossed midnight
    }

    final diff = endTotal - startTotal;
    if (diff <= 0) return null;

    final hours = diff ~/ 60;
    final mins = diff % 60;

    if (hours > 0 && mins > 0) {
      return '$hours giờ $mins phút';
    } else if (hours > 0) {
      return '$hours giờ';
    } else {
      return '$mins phút';
    }
  }

  Future<void> _launchDirections(BuildContext context, double lat, double lon) async {
    final uri = NavigationLauncherHelper.buildGoogleMapsUri(
      waypoints: [LatLng(lat, lon)],
    );
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể mở ứng dụng bản đồ bên ngoài.'),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể mở liên kết bản đồ.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final act = activity;

    // Handle invalid or missing activity safely
    if (act == null || act.name.trim().isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Chi tiết hoạt động'),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: Center(
          child: AppEmptyState(
            title: 'Không tìm thấy hoạt động',
            message: 'Thông tin hoạt động không tồn tại hoặc dữ liệu không còn hợp lệ.',
            icon: Icons.search_off_outlined,
            actionText: 'Quay lại',
            onActionPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final effectiveImage = (act.imageUrl != null && act.imageUrl!.trim().isNotEmpty)
        ? act.imageUrl!.trim()
        : act.destination?.imageUrl?.trim();

    final locationName = act.effectiveLocationName?.trim();
    final address = act.effectiveAddress?.trim();
    final hasLocation = (locationName != null && locationName.isNotEmpty) ||
        (address != null && address.isNotEmpty);
    final hasCoords = act.hasCoordinates;
    final duration = calculateDuration(act.startTime, act.endTime);
    final timeFormatted = act.timeRangeFormatted;
    final hasDescription = act.description != null && act.description!.trim().isNotEmpty;
    final hasCost = act.estimatedCost != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết hoạt động'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.hairlineSoft),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image Header (if exists)
            if (effectiveImage != null && effectiveImage.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  effectiveImage,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 220,
                      color: AppColors.surfaceSoft,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Day & Order Metadata Chip
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (dayNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dayTitle != null && dayTitle!.trim().isNotEmpty
                              ? 'Ngày $dayNumber: ${dayTitle!.trim()}'
                              : 'Ngày $dayNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (act.displayOrder > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairlineSoft),
                    ),
                    child: Text(
                      'Thứ tự #${act.displayOrder}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (act.activityType != null && act.activityType!.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      act.activityType!.trim().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Activity Name
            Text(
              act.name.trim(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // 4. Quick Highlights Grid (Time, Duration, Cost)
            if (timeFormatted != null || hasCost) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Column(
                  children: [
                    if (timeFormatted != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.hairlineSoft),
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Thời gian',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeFormatted,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (duration != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Thời lượng ước tính: $duration',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (timeFormatted != null && hasCost)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: AppColors.hairlineSoft),
                      ),
                    if (hasCost)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.hairlineSoft),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Chi phí dự kiến',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatCost(act.estimatedCost!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: act.estimatedCost! > 0
                                        ? AppColors.textPrimary
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 5. Detailed Description Section (if present)
            if (hasDescription) ...[
              const Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Mô tả chi tiết',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Text(
                  act.description!.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 6. Location & Address Section
            const Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 6),
                Text(
                  'Địa điểm thực hiện',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairlineSoft),
              ),
              child: hasLocation || hasCoords
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (locationName != null && locationName.isNotEmpty) ...[
                          Text(
                            locationName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (address != null && address.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.location_on,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (hasCoords) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.gps_fixed,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${act.effectiveLatitude!.toStringAsFixed(5)}, ${act.effectiveLongitude!.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  side: const BorderSide(color: AppColors.hairline),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.directions_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                label: const Text(
                                  'Chỉ đường',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                onPressed: () => _launchDirections(
                                  context,
                                  act.effectiveLatitude!,
                                  act.effectiveLongitude!,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    )
                  : const Row(
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hoạt động này chưa có thông tin địa điểm cụ thể.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // 7. Interactive Map Section (only when coordinates exist)
            if (hasCoords) ...[
              const Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Vị trí trên bản đồ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppMapView(
                    initialCenter: LatLng(
                      act.effectiveLatitude!,
                      act.effectiveLongitude!,
                    ),
                    initialZoom: 15.0,
                    markers: [
                      Marker(
                        point: LatLng(
                          act.effectiveLatitude!,
                          act.effectiveLongitude!,
                        ),
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.place,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 8. Catalog Destination Extra Information (if destination object exists)
            if (act.destination != null &&
                act.destination!.description != null &&
                act.destination!.description!.trim().isNotEmpty) ...[
              const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Thông tin điểm đến',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairlineSoft),
                ),
                child: Text(
                  act.destination!.description!.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textBody,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 9. Read-only hint at the bottom
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    Text(
                      'Chế độ xem chi tiết (chỉ đọc)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() => Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairlineSoft),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 32,
              color: AppColors.muted,
            ),
            SizedBox(height: 6),
            Text(
              'Không thể tải hình ảnh hoạt động',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}
