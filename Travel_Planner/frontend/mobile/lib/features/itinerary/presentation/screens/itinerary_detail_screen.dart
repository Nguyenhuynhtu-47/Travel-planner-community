import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../data/itinerary_repository.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/itinerary_day_detail.dart';
import '../../data/models/itinerary_detail.dart';
import '../../data/models/itinerary_place.dart';
import '../../data/models/place_summary.dart';
import '../itinerary_detail_notifier.dart';
import '../widgets/activity_form_dialog.dart';
import '../widgets/day_form_dialog.dart';
import '../widgets/delete_activity_dialog.dart';
import '../widgets/delete_day_dialog.dart';
import '../widgets/delete_itinerary_dialog.dart';
import '../widgets/itinerary_day_card.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../comments/presentation/widgets/itinerary_comments_section.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/models/reorder_activity_item.dart';
import '../widgets/reorder_activities_dialog.dart';
import '../widgets/itinerary_map_preview_card.dart';
import 'activity_detail_screen.dart';
import 'edit_itinerary_screen.dart';
import 'itinerary_map_screen.dart';
import '../../../social/data/social_repository.dart';
import '../../../social/data/models/social_state_update.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final int itineraryId;
  final String? token;
  final ItinerarySummary? initialSummary;
  final ItineraryDetail? initialDetail;
  final bool? isOwner;
  final bool? initialIsFavorited;
  final bool? initialIsSaved;
  final ItineraryDetailNotifier? notifier;
  final AuthNotifier? authNotifier;
  final ItineraryCrudRepository? crudRepository;
  final SocialRepository? socialRepository;
  final ValueChanged<SocialStateUpdate>? onSocialUpdate;

  const ItineraryDetailScreen({
    super.key,
    required this.itineraryId,
    this.token,
    this.initialSummary,
    this.initialDetail,
    this.initialIsFavorited,
    this.initialIsSaved,
    this.isOwner,
    this.notifier,
    this.authNotifier,
    this.crudRepository,
    this.socialRepository,
    this.onSocialUpdate,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  late final ItineraryDetailNotifier _notifier;
  late final ItineraryCrudRepository _crudRepository;
  late final SocialRepository _socialRepository;
  bool _isDeleting = false;
  bool _isCloning = false;
  int? _selectedDayNumber;
  bool? _userFavoritedOverride;
  bool? _userSavedOverride;
  int? _userRatingOverride;
  bool _userRatingCleared = false;
  double? _averageRatingOverride;
  int? _ratingCountOverride;
  int? _favoriteCountOverride;
  bool _hasSocialChanges = false;
  bool _isTogglingFavorite = false;
  bool _isTogglingSave = false;
  List<ItineraryPlace> _itinerarySavedPlaces = [];
  bool _isLoadingSavedPlaces = false;

  String? get _effectiveToken => widget.token ?? widget.authNotifier?.token;

  @override
  void initState() {
    super.initState();
    _notifier =
        widget.notifier ??
        ItineraryDetailNotifier(
          itineraryId: widget.itineraryId,
          initialSummary: widget.initialSummary,
          initialDetail: widget.initialDetail,
          initialIsFavorited: widget.initialIsFavorited,
          initialIsSaved: widget.initialIsSaved,
          repository: ItineraryRepository(
            apiClient: widget.crudRepository?.apiClient,
          ),
        );
    _crudRepository = widget.crudRepository ?? ItineraryCrudRepository();
    _socialRepository = widget.socialRepository ?? SocialRepository();
    if (widget.initialDetail != null) {
      _userFavoritedOverride = widget.initialDetail!.isFavorited;
      _userSavedOverride = widget.initialDetail!.isSaved;
      _userRatingOverride = widget.initialDetail!.userRating;
      _averageRatingOverride = widget.initialDetail!.averageRating;
      _ratingCountOverride = widget.initialDetail!.ratingCount;
      _favoriteCountOverride = widget.initialDetail!.favoriteCount;
    } else {
      if (widget.initialIsFavorited != null) {
        _userFavoritedOverride = widget.initialIsFavorited;
      }
      if (widget.initialIsSaved != null) {
        _userSavedOverride = widget.initialIsSaved;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.loadDetail(token: _effectiveToken);
        _loadItinerarySavedPlaces();
      }
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

  Future<void> _handleClone(ItineraryDetail itinerary) async {
    if (_isCloning) return;

    final isAuthenticated = widget.authNotifier?.isAuthenticated ?? false;
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để sao chép lịch trình'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sao chép lịch trình'),
        content: Text(
          'Bạn có muốn tạo một bản sao độc lập của lịch trình "${itinerary.title}"? '
          'Bản sao sẽ thuộc quyền sở hữu của bạn và bạn có thể tự do tùy chỉnh các ngày, hoạt động và địa điểm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCloning = true);

    try {
      final clonedItinerary = await _crudRepository.cloneItinerary(
        itinerary.itineraryId,
        token: _effectiveToken,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép lịch trình thành công!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ItineraryDetailScreen(
            itineraryId: clonedItinerary.itineraryId,
            initialDetail: clonedItinerary,
            authNotifier: widget.authNotifier,
            isOwner: true,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể sao chép lịch trình: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCloning = false);
      }
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

  Future<void> _handleAddActivity(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
  ) async {
    if (widget.authNotifier == null) return;

    final result = await showActivityFormDialog(
      context,
      itineraryId: itinerary.itineraryId,
      dayId: day.dayId,
      dayNumber: day.dayNumber,
      dayTitle: day.title,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm hoạt động mới thành công.'),
          backgroundColor: AppColors.success,
        ),
      );
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<void> _handleEditActivity(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
    ActivityDetail activity,
  ) async {
    if (widget.authNotifier == null) return;

    final result = await showActivityFormDialog(
      context,
      itineraryId: itinerary.itineraryId,
      dayId: day.dayId,
      dayNumber: day.dayNumber,
      dayTitle: day.title,
      initialActivity: activity,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật hoạt động thành công.'),
          backgroundColor: AppColors.success,
        ),
      );
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<void> _handleDeleteActivity(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
    ActivityDetail activity,
  ) async {
    if (widget.authNotifier == null) return;

    final confirmed = await showDeleteActivityConfirmationDialog(
      context,
      activityName: activity.name,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _crudRepository.deleteActivity(
        itinerary.itineraryId,
        day.dayId,
        activity.activityId,
        token: _effectiveToken,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa hoạt động "${activity.name}" thành công.'),
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
          content: Text('Không thể xóa hoạt động. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleViewActivityDetail(
    ActivityDetail activity,
    ItineraryDayDetail day,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailScreen(
          activity: activity,
          dayNumber: day.dayNumber,
          dayTitle: day.title,
          itineraryTitle: _notifier.itineraryDetail?.title,
        ),
      ),
    );
  }

  Future<void> _handleReorderActivities(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
  ) async {
    if (widget.authNotifier == null) return;

    final result = await showReorderActivitiesDialog(
      context,
      itineraryId: itinerary.itineraryId,
      dayId: day.dayId,
      dayNumber: day.dayNumber,
      activities: day.activities,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thứ tự hoạt động.'),
          backgroundColor: AppColors.success,
        ),
      );
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<bool> _handleSaveActivityOrder(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
    List<ReorderActivityItem> items,
  ) async {
    final token = _effectiveToken;
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để sắp xếp hoạt động.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }

    try {
      await _crudRepository.reorderActivities(
        itinerary.itineraryId,
        day.dayId,
        items,
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thứ tự hoạt động.'),
            backgroundColor: AppColors.success,
          ),
        );
        _notifier.loadDetail(token: _effectiveToken);
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu thứ tự hoạt động. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

  void _openFullScreenMap(ItineraryDetail itinerary) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItineraryMapScreen(
          itinerary: itinerary,
          initialDayNumber: _selectedDayNumber,
          token: _effectiveToken,
        ),
      ),
    );
  }

  SocialStateUpdate _buildSocialUpdate([ItineraryDetail? itinerary]) {
    final detail = itinerary ?? _notifier.itineraryDetail;
    return SocialStateUpdate(
      itineraryId: widget.itineraryId,
      isFavorited: _userFavoritedOverride ?? detail?.isFavorited,
      isSaved: _userSavedOverride ?? detail?.isSaved,
      userRating: _userRatingCleared
          ? null
          : (_userRatingOverride ?? detail?.userRating),
      averageRating: _averageRatingOverride ?? detail?.averageRating,
      ratingCount: _ratingCountOverride ?? detail?.ratingCount,
      favoriteCount: _favoriteCountOverride ?? detail?.favoriteCount,
    );
  }

  Future<void> _handleToggleSave(ItineraryDetail itinerary) async {
    if (widget.authNotifier != null && !widget.authNotifier!.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để lưu lịch trình.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentSaved = _userSavedOverride ?? itinerary.isSaved;
    final nextSaved = !currentSaved;

    setState(() {
      _isTogglingSave = true;
    });

    try {
      if (nextSaved) {
        await _socialRepository.saveItinerary(
          itinerary.itineraryId,
          token: _effectiveToken,
        );
      } else {
        await _socialRepository.removeSavedItinerary(
          itinerary.itineraryId,
          token: _effectiveToken,
        );
      }
      setState(() {
        _userSavedOverride = nextSaved;
        _hasSocialChanges = true;
      });
      final update = _buildSocialUpdate(itinerary);
      widget.onSocialUpdate?.call(update);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextSaved ? 'Đã lưu lịch trình' : 'Đã bỏ lưu lịch trình',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingSave = false;
        });
      }
    }
  }

  Future<void> _handleToggleFavorite(
    ItineraryDetail itinerary,
    bool isOwner,
  ) async {
    if (widget.authNotifier != null && !widget.authNotifier!.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để lưu lịch trình yêu thích.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể tự yêu thích lịch trình của mình'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentFav = _userFavoritedOverride ?? itinerary.isFavorited;
    final nextFav = !currentFav;
    final currentCount = _favoriteCountOverride ?? itinerary.favoriteCount;
    final nextCount = nextFav
        ? currentCount + 1
        : (currentCount > 0 ? currentCount - 1 : 0);

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      if (nextFav) {
        await _socialRepository.addFavorite(
          itinerary.itineraryId,
          token: _effectiveToken,
        );
      } else {
        await _socialRepository.removeFavorite(
          itinerary.itineraryId,
          token: _effectiveToken,
        );
      }
      setState(() {
        _userFavoritedOverride = nextFav;
        _favoriteCountOverride = nextCount;
        _hasSocialChanges = true;
      });
      final update = _buildSocialUpdate(itinerary);
      widget.onSocialUpdate?.call(update);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextFav ? 'Đã thêm vào yêu thích' : 'Đã bỏ yêu thích lịch trình',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  Future<void> _openRatingDialog(
    ItineraryDetail itinerary,
    bool isOwner,
  ) async {
    if (widget.authNotifier != null && !widget.authNotifier!.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để đánh giá lịch trình.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể tự đánh giá lịch trình của mình'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentRating = _userRatingCleared
        ? null
        : (_userRatingOverride ?? itinerary.userRating);
    final initialScore = currentRating ?? 5;
    int selectedScore = initialScore;
    final hasExistingRating = currentRating != null;

    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actionsOverflowButtonSpacing: 8,
              actionsAlignment: MainAxisAlignment.end,
              title: Text(
                hasExistingRating ? 'Cập nhật đánh giá' : 'Đánh giá lịch trình',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chọn số sao để đánh giá lịch trình này:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          final isSelected = starValue <= selectedScore;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip: '$starValue sao',
                              icon: Icon(
                                isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 36,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  selectedScore = starValue;
                                });
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$selectedScore sao',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                if (hasExistingRating)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(-1),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Xóa đánh giá'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(selectedScore),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Gửi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    if (result == -1) {
      try {
        await _socialRepository.deleteRating(
          itinerary.itineraryId,
          token: _effectiveToken,
        );
        final currentCount = _ratingCountOverride ?? itinerary.ratingCount;
        setState(() {
          _userRatingOverride = null;
          _userRatingCleared = true;
          _ratingCountOverride = currentCount > 0 ? currentCount - 1 : 0;
          _hasSocialChanges = true;
        });
        final update = _buildSocialUpdate(itinerary);
        widget.onSocialUpdate?.call(update);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã xóa đánh giá')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      try {
        final response = await _socialRepository.rateItinerary(
          itinerary.itineraryId,
          result,
          token: _effectiveToken,
        );
        setState(() {
          _userRatingOverride = result;
          _userRatingCleared = false;
          if (response['averageRating'] is num) {
            _averageRatingOverride = (response['averageRating'] as num)
                .toDouble();
          }
          if (response['ratingCount'] is num) {
            _ratingCountOverride = (response['ratingCount'] as num).toInt();
          }
          _hasSocialChanges = true;
        });
        final update = _buildSocialUpdate(itinerary);
        widget.onSocialUpdate?.call(update);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi đánh giá thành công')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final itinerary = _notifier.itineraryDetail;
        final currentUsername = widget.authNotifier?.currentUser?['username']
            ?.toString()
            .trim();
        final currentUserId = widget.authNotifier?.currentUser?['userId'] is num
            ? (widget.authNotifier!.currentUser!['userId'] as num).toInt()
            : int.tryParse(
                widget.authNotifier?.currentUser?['userId']?.toString() ?? '',
              );
        final creatorUsername = itinerary?.creator?.username.trim();
        final creatorUserId = itinerary?.creator?.userId;

        final isOwner =
            widget.isOwner == true ||
            ((currentUserId != null &&
                    creatorUserId != null &&
                    creatorUserId != 0 &&
                    currentUserId == creatorUserId) ||
                (currentUsername != null &&
                    creatorUsername != null &&
                    creatorUsername.isNotEmpty &&
                    creatorUsername.toLowerCase() != 'anonymous' &&
                    currentUsername.toLowerCase() ==
                        creatorUsername.toLowerCase()));

        final effectiveSaved =
            _userSavedOverride ?? itinerary?.isSaved ?? false;
        final effectiveFavorited =
            _userFavoritedOverride ?? itinerary?.isFavorited ?? false;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop && _hasSocialChanges) {
              widget.onSocialUpdate?.call(_buildSocialUpdate(itinerary));
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Chi tiết lịch trình'),
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Quay lại',
                onPressed: () {
                  Navigator.of(context).pop(
                    _hasSocialChanges ? _buildSocialUpdate(itinerary) : null,
                  );
                },
              ),
              actions: [
                if (itinerary != null) ...[
                  IconButton(
                    icon: Icon(
                      effectiveSaved
                          ? Icons.bookmark
                          : Icons.bookmark_border_rounded,
                      color: effectiveSaved
                          ? AppColors.savedActive
                          : AppColors.textPrimary,
                    ),
                    tooltip: effectiveSaved ? 'Bỏ lưu' : 'Lưu lịch trình',
                    onPressed: _isTogglingSave
                        ? null
                        : () => _handleToggleSave(itinerary),
                  ),
                  IconButton(
                    icon: Icon(
                      effectiveFavorited
                          ? Icons.favorite
                          : Icons.favorite_border_rounded,
                      color: effectiveFavorited
                          ? Colors.redAccent
                          : AppColors.textPrimary,
                    ),
                    tooltip: effectiveFavorited ? 'Bỏ yêu thích' : 'Yêu thích',
                    onPressed: _isTogglingFavorite
                        ? null
                        : () => _handleToggleFavorite(itinerary, isOwner),
                  ),
                  if (_isCloning)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
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
                  else
                    IconButton(
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: 'Sao chép lịch trình',
                      onPressed: () => _handleClone(itinerary),
                    ),
                ],
                if (isOwner && itinerary != null) ...[
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
                      icon: const Icon(Icons.bookmark_add_outlined),
                      tooltip: 'Lưu địa điểm vào lịch trình',
                      onPressed: _showAddPlaceToItineraryDialog,
                    ),
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
          ),
        );
      },
    );
  }

  Widget _buildBody(ItineraryDetail? itinerary, bool isOwner) {
    if (itinerary != null) {
      return _buildContent(itinerary, isOwner);
    }
    if (_notifier.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_notifier.isUnauthorized) {
      return AppEmptyState(
        title: 'Không có quyền truy cập',
        message:
            _notifier.errorMessage ??
            'Lịch trình này ở chế độ riêng tư và chỉ người tạo mới có thể xem.',
        icon: Icons.lock_outline,
      );
    }
    if (_notifier.isNotFound) {
      return const AppEmptyState(
        title: 'Không tìm thấy lịch trình',
        message: 'Lịch trình không tồn tại hoặc đã bị xóa.',
        icon: Icons.luggage_outlined,
      );
    }
    if (_notifier.isNetworkError) {
      return AppErrorState(
        title: 'Lỗi kết nối',
        message:
            _notifier.errorMessage ??
            'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
        onRetry: () => _notifier.retry(token: _effectiveToken),
      );
    }
    if (_notifier.errorMessage != null) {
      return AppErrorState(
        title: 'Không thể tải lịch trình',
        message: _notifier.errorMessage!,
        onRetry: () => _notifier.retry(token: _effectiveToken),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildContent(ItineraryDetail itinerary, bool isOwner) {
    if (_selectedDayNumber != null &&
        !itinerary.days.any((d) => d.dayNumber == _selectedDayNumber)) {
      _selectedDayNumber = null;
    }

    final displayedDays = _selectedDayNumber == null
        ? itinerary.days
        : itinerary.days
              .where((d) => d.dayNumber == _selectedDayNumber)
              .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          _notifier.loadDetail(token: _effectiveToken),
          _loadItinerarySavedPlaces(),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_notifier.isLoading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceSoft,
              ),
            ),
          if (_notifier.errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.error.withAlpha(20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _notifier.errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _notifier.retry(token: _effectiveToken),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 1. Compact Header
          SliverToBoxAdapter(child: _buildOverview(itinerary, isOwner)),

          // 1.1 Itinerary-scoped Saved Places
          SliverToBoxAdapter(child: _buildItinerarySavedPlaces(itinerary, isOwner)),

          // 2. Day Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lịch trình theo ngày (${itinerary.days.length} ngày)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isOwner)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
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

          // 3. Compact Horizontal Day Selector
          if (itinerary.days.isNotEmpty)
            SliverToBoxAdapter(child: _buildDaySelector(itinerary)),

          // 3.1. Embedded Itinerary Map Preview Card
          if (itinerary.days.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: ItineraryMapPreviewCard(
                  itinerary: itinerary,
                  selectedDayNumber: _selectedDayNumber,
                  onOpenFullScreen: () => _openFullScreenMap(itinerary),
                ),
              ),
            ),

          // 4. Days Content
          if (itinerary.days.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: AppEmptyState(
                  title: 'Chưa có lịch trình theo ngày',
                  message: 'Lịch trình này chưa có ngày hoặc hoạt động được lên kế hoạch.',
                  icon: Icons.calendar_today_outlined,
                  actionText: isOwner ? 'Thêm ngày đầu tiên' : null,
                  onActionPressed: isOwner
                      ? () => _handleAddDay(itinerary)
                      : null,
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              sliver: SliverList.builder(
                itemCount: displayedDays.length,
                itemBuilder: (context, index) {
                  final day = displayedDays[index];
                    return ItineraryDayCard(
                      day: day,
                      onEdit: isOwner
                          ? () => _handleEditDay(itinerary, day)
                          : null,
                      onDelete: isOwner
                          ? () => _handleDeleteDay(itinerary, day)
                          : null,
                      onAddActivity: isOwner
                          ? () => _handleAddActivity(itinerary, day)
                          : null,
                      onEditActivity: isOwner
                          ? (act) => _handleEditActivity(itinerary, day, act)
                          : null,
                      onDeleteActivity: isOwner
                          ? (act) => _handleDeleteActivity(itinerary, day, act)
                          : null,
                      onActivityTap: (act) =>
                          _handleViewActivityDetail(act, day),
                      onActivityComments: !isOwner &&
                              itinerary.visibility == 'PUBLIC' &&
                              (itinerary.status == 'ACTIVE' ||
                                  itinerary.status == 'PUBLISHED')
                          ? (act) =>
                                _openActivityComments(act.activityId, act.name)
                          : null,
                      onReorderActivities: isOwner
                          ? () => _handleReorderActivities(itinerary, day)
                          : null,
                      onSaveActivityOrder: isOwner
                          ? (items) =>
                                _handleSaveActivityOrder(itinerary, day, items)
                          : null,
                    );
                },
              ),
            ),
            if (isOwner && _selectedDayNumber == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.hairline),
                      backgroundColor: AppColors.surfaceSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.primary,
                    ),
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
            if (_selectedDayNumber != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.hairline),
                      backgroundColor: AppColors.surfaceSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.view_agenda_outlined,
                      color: AppColors.textSecondary,
                    ),
                    label: const Text(
                      'Xem toàn bộ các ngày',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => setState(() => _selectedDayNumber = null),
                  ),
                ),
              ),
          ],
          if ((itinerary.status == 'ACTIVE' ||
                  itinerary.status == 'PUBLISHED') &&
              itinerary.visibility == 'PUBLIC') ...[
            if (!isOwner)
              SliverToBoxAdapter(
                child: ItineraryCommentsSection(
                  itineraryId: itinerary.itineraryId,
                  token: _effectiveToken,
                  authNotifier: widget.authNotifier,
                ),
              ),
            SliverToBoxAdapter(child: _buildRatingSection(itinerary, isOwner)),
          ],
        ],
      ),
    );
  }

  void _openActivityComments(int activityId, String activityName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final availableHeight =
            mediaQuery.size.height - mediaQuery.viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: SizedBox(
            height: availableHeight * 0.82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.md,
                    AppSpacing.base,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          activityName,
                          style: AppTextStyles.titleMd.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: ActivityCommentsSection(
                      activityId: activityId,
                      token: _effectiveToken,
                      authNotifier: widget.authNotifier,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCreatorProfile(int userId) {
    final currentId = int.tryParse(
      '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => currentId == userId && widget.authNotifier != null
            ? ProfileScreen(authNotifier: widget.authNotifier!)
            : PublicProfileScreen(
                userId: userId,
                authNotifier: widget.authNotifier,
              ),
      ),
    );
  }

  Widget _buildDaySelector(ItineraryDetail itinerary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _buildDayChip(
            label: 'Tất cả (${itinerary.days.length})',
            isSelected: _selectedDayNumber == null,
            onSelected: () => setState(() => _selectedDayNumber = null),
          ),
          for (final day in itinerary.days)
            _buildDayChip(
              label: 'Ngày ${day.dayNumber} (${day.activities.length})',
              isSelected: _selectedDayNumber == day.dayNumber,
              onSelected: () =>
                  setState(() => _selectedDayNumber = day.dayNumber),
            ),
        ],
      ),
    );
  }

  Widget _buildDayChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceSoft,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.hairline,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildRatingSection(ItineraryDetail itinerary, bool isOwner) {
    final effectiveUserRating = _userRatingCleared
        ? null
        : (_userRatingOverride ?? itinerary.userRating);
    final effectiveAverageRating =
        _averageRatingOverride ?? itinerary.averageRating;
    final effectiveRatingCount = _ratingCountOverride ?? itinerary.ratingCount;
    final hasUserRating = effectiveUserRating != null;
    final isGuest =
        widget.authNotifier != null && !widget.authNotifier!.isAuthenticated;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Đánh giá ($effectiveRatingCount)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (!isOwner && !isGuest)
                TextButton.icon(
                  onPressed: () => _openRatingDialog(itinerary, isOwner),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: Icon(
                    hasUserRating
                        ? Icons.edit_outlined
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    hasUserRating ? 'Sửa đánh giá' : 'Đánh giá ngay',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Rating Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Average rating score (large)
                    Text(
                      effectiveRatingCount > 0
                          ? effectiveAverageRating.toStringAsFixed(1)
                          : '0.0',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stars display
                          Row(
                            children: List.generate(5, (index) {
                              final starThreshold = index + 1;
                              final isFilled =
                                  effectiveRatingCount > 0 &&
                                  (effectiveAverageRating >= starThreshold ||
                                      (effectiveAverageRating >=
                                          starThreshold - 0.25));
                              final isHalf =
                                  effectiveRatingCount > 0 &&
                                  !isFilled &&
                                  effectiveAverageRating >=
                                      starThreshold - 0.75;
                              return Icon(
                                isFilled
                                    ? Icons.star_rounded
                                    : (isHalf
                                          ? Icons.star_half_rounded
                                          : Icons.star_outline_rounded),
                                color: Colors.amber,
                                size: 20,
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            effectiveRatingCount > 0
                                ? '$effectiveRatingCount lượt đánh giá'
                                : 'Chưa có lượt đánh giá nào',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Divider and user rating status
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 12),

                // Status row based on viewer role and user rating state
                if (isOwner)
                  Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bạn là người tạo lịch trình này (không thể tự đánh giá)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isGuest)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Đăng nhập để đánh giá lịch trình này',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openRatingDialog(itinerary, isOwner),
                        child: const Text('Đánh giá'),
                      ),
                    ],
                  )
                else if (hasUserRating)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Đánh giá của bạn: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < effectiveUserRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 18,
                                );
                              }),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($effectiveUserRating sao)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _openRatingDialog(itinerary, isOwner),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'Chỉnh sửa',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Bạn đã trải nghiệm lịch trình này chưa?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _openRatingDialog(itinerary, isOwner),
                        icon: const Icon(
                          Icons.star_outline_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Đánh giá',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(ItineraryDetail itinerary, bool isOwner) {
    final imageUrl = itinerary.coverImage?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Cover Image Banner (110dp if image present, 64dp if placeholder)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: hasImage ? 110 : 76,
              width: double.infinity,
              child: hasImage
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _imagePlaceholder(itinerary.location),
                    )
                  : _imagePlaceholder(itinerary.location),
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            itinerary.title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Essential Summary Metadata Badges
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _meta(Icons.location_on_outlined, itinerary.location),
              _meta(
                Icons.calendar_month_outlined,
                '${itinerary.totalDays} ngày',
              ),
              _meta(
                itinerary.visibility == 'PUBLIC'
                    ? Icons.public
                    : Icons.lock_outline,
                itinerary.visibility == 'PUBLIC' ? 'Công khai' : 'Riêng tư',
              ),
              if (itinerary.theme != null && itinerary.theme!.trim().isNotEmpty)
                _meta(Icons.category_outlined, itinerary.theme!.trim()),
              _meta(Icons.payments_outlined, _formatBudget(itinerary.budget)),
              if (itinerary.reuseCount > 0)
                _meta(
                  Icons.copy_all_outlined,
                  '${itinerary.reuseCount} lượt sao chép',
                ),
            ],
          ),

          // Secondary Details: Creator & Description in compact box
          if (itinerary.creator != null ||
              (itinerary.description != null &&
                  itinerary.description!.trim().isNotEmpty)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.hairlineSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (itinerary.creator != null) ...[
                    InkWell(
                      onTap: itinerary.creator!.userId == 0
                          ? null
                          : () =>
                                _openCreatorProfile(itinerary.creator!.userId),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          _creatorAvatar(itinerary.creator!.avatar),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              itinerary.creator!.displayName != 'anonymous'
                                  ? 'Tạo bởi ${itinerary.creator!.displayName}'
                                  : (itinerary.creator!.userId != 0
                                        ? 'Tạo bởi Người dùng #${itinerary.creator!.userId}'
                                        : 'Tạo bởi người dùng ẩn danh'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    itinerary.description != null &&
                            itinerary.description!.trim().isNotEmpty
                        ? itinerary.description!.trim()
                        : 'Chưa có mô tả cho lịch trình này.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontStyle:
                          itinerary.description == null ||
                              itinerary.description!.trim().isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color:
                          itinerary.description == null ||
                              itinerary.description!.trim().isEmpty
                          ? AppColors.textSecondary
                          : AppColors.textBody,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
      onBackgroundImageError: imageUrl != null && imageUrl.isNotEmpty
          ? (error, stack) {}
          : null,
      child: imageUrl == null || imageUrl.isEmpty
          ? const Icon(Icons.person_outline, color: AppColors.muted)
          : null,
    );
  }

  Widget _imagePlaceholder(String location) => Container(
    color: AppColors.surfaceSoft,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.landscape_outlined, size: 28, color: AppColors.muted),
        if (location.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Future<void> _loadItinerarySavedPlaces() async {
    try {
      setState(() => _isLoadingSavedPlaces = true);
      final places = await _crudRepository.getSavedPlaces(
        widget.itineraryId,
        token: _effectiveToken,
      );
      if (mounted) {
        setState(() {
          _itinerarySavedPlaces = places;
          _isLoadingSavedPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSavedPlaces = false);
      }
    }
  }

  Future<void> _handleSavePlaceToItinerary(PlaceSummary place) async {
    if (_effectiveToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để lưu địa điểm vào lịch trình.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    try {
      await _crudRepository.savePlaceToItinerary(
        widget.itineraryId,
        place.placeId,
        token: _effectiveToken!,
      );
      await _loadItinerarySavedPlaces();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu "${place.name}" vào lịch trình!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Lỗi khi lưu địa điểm'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveSavedPlace(ItineraryPlace ip) async {
    if (_effectiveToken == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ lưu địa điểm'),
        content: Text(
          'Bạn có chắc chắn muốn bỏ lưu "${ip.place.name}" khỏi lịch trình này? Các hoạt động trong lịch trình sẽ không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bỏ lưu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _crudRepository.removePlaceFromItinerary(
        widget.itineraryId,
        ip.place.placeId,
        token: _effectiveToken!,
      );
      await _loadItinerarySavedPlaces();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${ip.place.name}" khỏi danh sách lưu của lịch trình.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Lỗi khi xóa địa điểm'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddPlaceToItineraryDialog() async {
    if (_effectiveToken == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPlaceToItinerarySheet(
        crudRepository: _crudRepository,
        token: _effectiveToken,
        existingPlaceIds: _itinerarySavedPlaces.map((e) => e.place.placeId).toSet(),
        onPlaceSelected: (place) {
          Navigator.of(ctx).pop();
          _handleSavePlaceToItinerary(place);
        },
      ),
    );
  }

  Widget _buildItinerarySavedPlaces(ItineraryDetail itinerary, bool isOwner) {
    if (_itinerarySavedPlaces.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_added_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Địa điểm đã lưu (${_itinerarySavedPlaces.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: _showAddPlaceToItineraryDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm địa điểm', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          if (_isLoadingSavedPlaces)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_itinerarySavedPlaces.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Lịch trình chưa có địa điểm nào được lưu. Hãy thêm các địa điểm để thuận tiện lập kế hoạch!',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _itinerarySavedPlaces.map((ip) {
                  return Chip(
                    avatar: const Icon(Icons.place, size: 16, color: AppColors.primary),
                    label: Text(
                      ip.place.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    deleteIcon: isOwner ? const Icon(Icons.close, size: 16) : null,
                    onDeleted: isOwner ? () => _handleRemoveSavedPlace(ip) : null,
                    backgroundColor: AppColors.surfaceSoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPlaceToItinerarySheet extends StatefulWidget {
  final ItineraryCrudRepository crudRepository;
  final String? token;
  final Set<int> existingPlaceIds;
  final ValueChanged<PlaceSummary> onPlaceSelected;

  const _AddPlaceToItinerarySheet({
    required this.crudRepository,
    required this.token,
    required this.existingPlaceIds,
    required this.onPlaceSelected,
  });

  @override
  State<_AddPlaceToItinerarySheet> createState() => _AddPlaceToItinerarySheetState();
}

class _AddPlaceToItinerarySheetState extends State<_AddPlaceToItinerarySheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSummary> _places = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaces({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.crudRepository.getPlaces(
        keyword: keyword,
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _places = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách địa điểm.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.bookmark_add_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Lưu địa điểm vào lịch trình',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm địa điểm...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                filled: true,
                fillColor: AppColors.surfaceSoft,
              ),
              onSubmitted: (query) => _fetchPlaces(keyword: query),
            ),
          ),
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            TextButton(
              onPressed: () => _fetchPlaces(keyword: _searchController.text),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_places.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy địa điểm nào.', style: TextStyle(color: AppColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _places.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        final place = _places[index];
        final alreadySaved = widget.existingPlaceIds.contains(place.placeId);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceSoft,
            child: Icon(
              Icons.place,
              color: alreadySaved ? AppColors.muted : AppColors.primary,
            ),
          ),
          title: Text(
            place.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: alreadySaved ? AppColors.muted : AppColors.textPrimary,
            ),
          ),
          subtitle: place.address != null
              ? Text(
                  place.address!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: alreadySaved ? AppColors.muted : AppColors.textSecondary,
                  ),
                )
              : null,
          trailing: alreadySaved
              ? const Chip(
                  label: Text('Đã lưu', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                )
              : FilledButton.tonal(
                  onPressed: () => widget.onPlaceSelected(place),
                  child: const Text('Lưu'),
                ),
        );
      },
    );
  }
}
