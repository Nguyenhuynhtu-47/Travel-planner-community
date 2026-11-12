import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../location/data/models/location_search_result.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/itinerary_repository.dart';
import '../../data/models/itinerary_day_detail.dart';

/// Modal bottom sheet allowing users to pick a specific day ([ItineraryDayDetail])
/// within an itinerary to schedule an activity into (Flow B).
class DayPickerBottomSheet extends StatefulWidget {
  final ItinerarySummary itinerary;
  final LocationSearchResult place;
  final String token;
  final ItineraryRepository? itineraryRepository;
  final ItineraryCrudRepository? crudRepository;

  const DayPickerBottomSheet({
    super.key,
    required this.itinerary,
    required this.place,
    required this.token,
    this.itineraryRepository,
    this.crudRepository,
  });

  /// Opens the [DayPickerBottomSheet], returning the chosen [ItineraryDayDetail].
  static Future<ItineraryDayDetail?> show(
    BuildContext context, {
    required ItinerarySummary itinerary,
    required LocationSearchResult place,
    required String token,
    ItineraryRepository? itineraryRepository,
    ItineraryCrudRepository? crudRepository,
  }) {
    return showModalBottomSheet<ItineraryDayDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => DayPickerBottomSheet(
        itinerary: itinerary,
        place: place,
        token: token,
        itineraryRepository: itineraryRepository,
        crudRepository: crudRepository,
      ),
    );
  }

  @override
  State<DayPickerBottomSheet> createState() => _DayPickerBottomSheetState();
}

class _DayPickerBottomSheetState extends State<DayPickerBottomSheet> {
  late final ItineraryRepository _itineraryRepository;
  bool _isLoading = true;
  String? _errorMessage;
  List<ItineraryDayDetail> _days = [];

  @override
  void initState() {
    super.initState();
    _itineraryRepository = widget.itineraryRepository ??
        ItineraryRepository(apiClient: widget.crudRepository?.apiClient);
    _loadDays();
  }

  Future<void> _loadDays() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _itineraryRepository.getItineraryDetail(
        widget.itinerary.itineraryId,
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _days = List.from(detail.days)
          ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message.isNotEmpty
            ? e.message
            : 'Không thể tải danh sách ngày trong lịch trình.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi kết nối máy chủ. Vui lòng thử lại sau.';
      });
    }
  }

  void _selectDay(ItineraryDayDetail day) {
    Navigator.of(context).pop(day);
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn ngày lên lịch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.itinerary.title} • ${widget.place.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairlineSoft),

              // Content Body
              Flexible(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadDays,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lịch trình chưa có ngày nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lịch trình này chưa có ngày nào. Vui lòng mở chi tiết lịch trình để thêm ngày trước.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _days.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.hairlineSoft),
      itemBuilder: (context, index) {
        final day = _days[index];
        final formattedDate =
            day.date != null ? _formatDate(day.date!) : null;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'NGÀY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${day.dayNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            day.displayTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (formattedDate != null) ...[
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('•', style: TextStyle(color: AppColors.muted)),
                const SizedBox(width: 6),
              ],
              Text(
                '${day.activities.length} hoạt động',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          trailing: FilledButton.tonal(
            key: Key('select_day_${day.dayId}'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _selectDay(day),
            child: const Text(
              'Chọn',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          onTap: () => _selectDay(day),
        );
      },
    );
  }
}
