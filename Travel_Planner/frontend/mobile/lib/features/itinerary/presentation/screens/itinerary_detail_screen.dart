import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../data/models/itinerary_detail.dart';
import '../itinerary_detail_notifier.dart';
import '../widgets/itinerary_day_card.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final int itineraryId;
  final String? token;
  final ItineraryDetailNotifier? notifier;

  const ItineraryDetailScreen({
    super.key,
    required this.itineraryId,
    this.token,
    this.notifier,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  late final ItineraryDetailNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier =
        widget.notifier ??
        ItineraryDetailNotifier(itineraryId: widget.itineraryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.loadDetail(token: widget.token);
    });
  }

  @override
  void dispose() {
    if (widget.notifier == null) _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết lịch trình'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) {
          if (_notifier.isLoading && _notifier.itineraryDetail == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final errorMessage = _notifier.errorMessage;
          if (errorMessage != null && _notifier.itineraryDetail == null) {
            return AppErrorState(
              title: 'Không thể tải lịch trình',
              message: errorMessage,
              onRetry: () => _notifier.retry(token: widget.token),
            );
          }

          final itinerary = _notifier.itineraryDetail;
          if (itinerary == null) {
            return const AppEmptyState(
              title: 'Không tìm thấy lịch trình',
              message: 'Lịch trình không tồn tại hoặc đã bị xóa.',
              icon: Icons.luggage_outlined,
            );
          }

          return _buildContent(itinerary);
        },
      ),
    );
  }

  Widget _buildContent(ItineraryDetail itinerary) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildOverview(itinerary)),
        if (itinerary.days.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'Chưa có lịch trình theo ngày',
              message: 'Lịch trình này chưa có ngày hoặc hoạt động được lên kế hoạch.',
              icon: Icons.calendar_today_outlined,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.builder(
              itemCount: itinerary.days.length,
              itemBuilder: (context, index) =>
                  ItineraryDayCard(day: itinerary.days[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildOverview(ItineraryDetail itinerary) {
    final imageUrl = itinerary.coverImage?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _imagePlaceholder(itinerary.location),
                )
              : _imagePlaceholder(itinerary.location),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itinerary.title,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _meta(Icons.location_on_outlined, itinerary.location),
                  _meta(
                    Icons.calendar_month_outlined,
                    '${itinerary.totalDays} ngày',
                  ),
                  _meta(
                    Icons.star_outline_rounded,
                    itinerary.ratingCount > 0
                        ? '${itinerary.averageRating.toStringAsFixed(1)} (${itinerary.ratingCount})'
                        : 'Chưa có đánh giá',
                  ),
                ],
              ),
              if (itinerary.creator != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _creatorAvatar(itinerary.creator!.avatar),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tạo bởi ${itinerary.creator!.displayName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (itinerary.description != null &&
                  itinerary.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  itinerary.description!.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Ngân sách dự kiến',
                      style: TextStyle(color: AppColors.textBody),
                    ),
                    const Spacer(),
                    Text(
                      _formatBudget(itinerary.budget),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Lịch trình theo ngày',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.textSecondary),
      const SizedBox(width: 5),
      Text(
        value,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _creatorAvatar(String? url) {
    final imageUrl = url?.trim();
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.surfaceSoft,
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl == null || imageUrl.isEmpty
          ? const Icon(Icons.person_outline, color: AppColors.muted)
          : null,
    );
  }

  Widget _imagePlaceholder(String location) => Container(
    color: AppColors.surfaceSoft,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.landscape_outlined, size: 48, color: AppColors.muted),
        if (location.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            location,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );

  String _formatBudget(double budget) {
    if (budget <= 0) return 'Chưa cập nhật';
    final formatted = budget.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }
}
