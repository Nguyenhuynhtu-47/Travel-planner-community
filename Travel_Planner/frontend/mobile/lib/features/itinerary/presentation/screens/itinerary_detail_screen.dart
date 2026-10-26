import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/models/itinerary_day_detail.dart';
import '../../data/models/itinerary_detail.dart';
import '../itinerary_detail_notifier.dart';
import '../widgets/day_form_dialog.dart';
import '../widgets/delete_day_dialog.dart';
import '../widgets/delete_itinerary_dialog.dart';
import '../widgets/itinerary_day_card.dart';
import 'edit_itinerary_screen.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final int itineraryId;
  final String? token;
  final ItineraryDetailNotifier? notifier;
  final AuthNotifier? authNotifier;
  final ItineraryCrudRepository? crudRepository;

  const ItineraryDetailScreen({
    super.key,
    required this.itineraryId,
    this.token,
    this.notifier,
    this.authNotifier,
    this.crudRepository,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  late final ItineraryDetailNotifier _notifier;
  late final ItineraryCrudRepository _crudRepository;
  bool _isDeleting = false;

  String? get _effectiveToken => widget.token ?? widget.authNotifier?.token;

  @override
  void initState() {
    super.initState();
    _notifier =
        widget.notifier ??
        ItineraryDetailNotifier(itineraryId: widget.itineraryId);
    _crudRepository = widget.crudRepository ?? ItineraryCrudRepository();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.loadDetail(token: _effectiveToken);
    });
  }

  @override
  void dispose() {
    if (widget.notifier == null) _notifier.dispose();
    super.dispose();
  }

  Future<void> _handleEdit(ItineraryDetail itinerary) async {
    if (widget.authNotifier == null) return;

    final updated = await Navigator.of(context).push<ItineraryDetail>(
      MaterialPageRoute<ItineraryDetail>(
        builder: (_) => EditItineraryScreen.fromDetail(
          itinerary,
          authNotifier: widget.authNotifier!,
          repository: _crudRepository,
        ),
      ),
    );

    if (updated != null && mounted) {
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<void> _handleDelete(ItineraryDetail itinerary) async {
    if (_isDeleting) return;

    final confirmed = await showDeleteItineraryConfirmationDialog(
      context,
      itineraryTitle: itinerary.title,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await _crudRepository.deleteItinerary(
        itinerary.itineraryId,
        token: _effectiveToken,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa lịch trình thành công.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Return true to indicate itinerary was deleted so parent screens can refresh
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa lịch trình. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleAddDay(ItineraryDetail itinerary) async {
    if (widget.authNotifier == null) return;

    final nextDayNumber = itinerary.days.isEmpty
        ? 1
        : itinerary.days.last.dayNumber + 1;

    final result = await showDayFormDialog(
      context,
      itineraryId: itinerary.itineraryId,
      nextDayNumber: nextDayNumber,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<void> _handleEditDay(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
  ) async {
    if (widget.authNotifier == null) return;

    final result = await showDayFormDialog(
      context,
      itineraryId: itinerary.itineraryId,
      initialDay: day,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<void> _handleDeleteDay(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
  ) async {
    if (widget.authNotifier == null) return;

    if (itinerary.days.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lịch trình phải có ít nhất 1 ngày. Không thể xóa ngày cuối cùng.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDeleteDayConfirmationDialog(
      context,
      dayNumber: day.dayNumber,
      dayTitle: day.title,
      hasActivities: day.activities.isNotEmpty,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _crudRepository.deleteDay(
        itinerary.itineraryId,
        day.dayId,
        token: _effectiveToken,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa Ngày ${day.dayNumber} thành công.'),
          backgroundColor: AppColors.success,
        ),
      );

      _notifier.loadDetail(token: _effectiveToken);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa ngày. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final itinerary = _notifier.itineraryDetail;
        final currentUsername =
            widget.authNotifier?.currentUser?['username']?.toString();
        final isOwner =
            currentUsername != null &&
            itinerary?.creator != null &&
            currentUsername == itinerary!.creator!.username;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Chi tiết lịch trình'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            surfaceTintColor: Colors.transparent,
            actions: [
              if (isOwner) ...[
                if (_isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Chỉnh sửa lịch trình',
                    onPressed: () => _handleEdit(itinerary),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    tooltip: 'Xóa lịch trình',
                    onPressed: () => _handleDelete(itinerary),
                  ),
                ],
              ],
            ],
          ),
          body: _buildBody(itinerary, isOwner),
        );
      },
    );
  }

  Widget _buildBody(ItineraryDetail? itinerary, bool isOwner) {
    if (_notifier.isLoading && itinerary == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final errorMessage = _notifier.errorMessage;
    if (errorMessage != null && itinerary == null) {
      return AppErrorState(
        title: 'Không thể tải lịch trình',
        message: errorMessage,
        onRetry: () => _notifier.retry(token: _effectiveToken),
      );
    }

    if (itinerary == null) {
      return const AppEmptyState(
        title: 'Không tìm thấy lịch trình',
        message: 'Lịch trình không tồn tại hoặc đã bị xóa.',
        icon: Icons.luggage_outlined,
      );
    }

    return _buildContent(itinerary, isOwner);
  }

  Widget _buildContent(ItineraryDetail itinerary, bool isOwner) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildOverview(itinerary)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lịch trình theo ngày (${itinerary.days.length} ngày)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isOwner)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Thêm ngày',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: () => _handleAddDay(itinerary),
                  ),
              ],
            ),
          ),
        ),
        if (itinerary.days.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              title: 'Chưa có lịch trình theo ngày',
              message: 'Lịch trình này chưa có ngày hoặc hoạt động được lên kế hoạch.',
              icon: Icons.calendar_today_outlined,
              actionText: isOwner ? 'Thêm ngày đầu tiên' : null,
              onActionPressed: isOwner ? () => _handleAddDay(itinerary) : null,
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverList.builder(
              itemCount: itinerary.days.length,
              itemBuilder: (context, index) {
                final day = itinerary.days[index];
                return ItineraryDayCard(
                  day: day,
                  onEdit: isOwner ? () => _handleEditDay(itinerary, day) : null,
                  onDelete: isOwner ? () => _handleDeleteDay(itinerary, day) : null,
                );
              },
            ),
          ),
          if (isOwner)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.hairline),
                    backgroundColor: AppColors.surfaceSoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  label: Text(
                    'Thêm Ngày ${itinerary.days.length + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _handleAddDay(itinerary),
                ),
              ),
            ),
        ],
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
