import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/sync/auto_refresh_lifecycle_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_header_button.dart';
import '../../../../shared/widgets/app_toast.dart';
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
import '../widgets/add_place_to_itinerary_sheet.dart';
import '../widgets/save_place_to_itinerary_sheet.dart';
import 'activity_detail_screen.dart';
import 'edit_itinerary_screen.dart';
import 'itinerary_map_screen.dart';
import '../../../social/data/social_repository.dart';
import '../../../social/data/models/social_state_update.dart';
import '../../../messaging/presentation/widgets/share_bottom_sheet.dart';

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
  final int initialTab;

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
    this.initialTab = 0,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen>
    with
        TickerProviderStateMixin,
        AutoRefreshLifecycleMixin<ItineraryDetailScreen> {
  late final ItineraryDetailNotifier _notifier;
  late final ItineraryCrudRepository _crudRepository;
  late final SocialRepository _socialRepository;
  late final TabController _tabController;
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

  String? get _effectiveToken => widget.token ?? widget.authNotifier?.token;

  @override
  Set<SyncDomain> get syncDomains => {
    SyncDomain.itineraries,
    SyncDomain.collections,
    SyncDomain.ratings,
  };

  @override
  Duration get syncTtl => const Duration(minutes: 2);

  @override
  Future<void> onRefreshData({bool isBackground = false}) async {
    await Future.wait([
      _notifier.loadDetail(token: _effectiveToken),
      _loadItinerarySavedPlaces(),
    ]);
  }

  @override
  void onSyncEvent(SyncEvent event) {
    if (!mounted) return;
    if (event.id == widget.itineraryId) {
      if (event.type == SyncEventType.saved ||
          event.type == SyncEventType.unsaved) {
        final payload = event.payload;
        if (payload is Map && payload['isSaved'] is bool) {
          setState(() {
            _userSavedOverride = payload['isSaved'] as bool;
          });
        }
        return;
      }
      if (event.type == SyncEventType.favorited ||
          event.type == SyncEventType.unfavorited) {
        final payload = event.payload;
        if (payload is Map && payload['isFavorited'] is bool) {
          setState(() {
            _userFavoritedOverride = payload['isFavorited'] as bool;
          });
        }
        return;
      }
      if (event.type == SyncEventType.reviewed) {
        final payload = event.payload;
        if (payload is Map) {
          setState(() {
            if (payload['rating'] is num) {
              _averageRatingOverride = (payload['rating'] as num).toDouble();
            }
            if (payload['count'] is num) {
              _ratingCountOverride = (payload['count'] as num).toInt();
            }
          });
        }
        return;
      }
      if (event.type == SyncEventType.updated) {
        onRefreshData(isBackground: true);
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _crudRepository = widget.crudRepository ?? ItineraryCrudRepository();
    _socialRepository = widget.socialRepository ?? SocialRepository();
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
          crudRepository: _crudRepository,
        );
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
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

  final ValueNotifier<bool> _isHeaderCollapsed = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHeaderCollapsed.dispose();
    _tabController.dispose();
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
      AppSyncBus.emitItineraryDeleted(itinerary.itineraryId);

      if (!mounted) return;

      AppToast.showSuccess(context, 'Đã xóa lịch trình thành công.');

      // Return true to indicate itinerary was deleted so parent screens can refresh
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppToast.showError(context, 'Không thể xóa lịch trình. Vui lòng thử lại.');
    }
  }

  Future<void> _handleClone(ItineraryDetail itinerary) async {
    if (_isCloning) return;

    final isAuthenticated = widget.authNotifier?.isAuthenticated ?? false;
    if (!isAuthenticated) {
      AppToast.showError(context, 'Vui lòng đăng nhập để sao chép lịch trình');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      type: AppDialogType.info,
      title: 'Sao chép lịch trình',
      message:
          'Bạn có muốn tạo một bản sao độc lập của lịch trình "${itinerary.title}"? '
          'Bản sao sẽ thuộc quyền sở hữu của bạn và bạn có thể tự do tùy chỉnh các ngày, hoạt động và địa điểm.',
      confirmText: 'Sao chép',
      cancelText: 'Hủy',
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCloning = true);

    try {
      final clonedItinerary = await _crudRepository.cloneItinerary(
        itinerary.itineraryId,
        token: _effectiveToken,
      );
      AppSyncBus.emitItineraryCreated(
        clonedItinerary,
        clonedItinerary.itineraryId,
      );

      if (!mounted) return;

      AppToast.showSuccess(context, 'Đã sao chép lịch trình thành công!');

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
      AppToast.showError(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Không thể sao chép lịch trình: $e');
    } finally {
      if (mounted) {
        setState(() => _isCloning = false);
      }
    }
  }

  void _handleShare(ItineraryDetail itinerary) {
    final isAuthenticated = widget.authNotifier?.isAuthenticated ?? false;
    if (!isAuthenticated) {
      AppToast.showInfo(context, 'Vui lòng đăng nhập để chia sẻ lịch trình');
      return;
    }

    ShareBottomSheet.show(
      context,
      targetType: 'ITINERARY',
      targetId: itinerary.itineraryId,
      title: itinerary.title,
      coverImage: itinerary.coverImage,
      subtitle: itinerary.location.isNotEmpty
          ? itinerary.location
          : '${itinerary.totalDays} ngày',
      authNotifier: widget.authNotifier,
    ).then((shared) {
      if (shared == true && mounted) {
        AppToast.showSuccess(context, 'Đã chia sẻ lịch trình thành công!');
      }
    });
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
      AppToast.showError(
        context,
        'Lịch trình phải có ít nhất 1 ngày. Không thể xóa ngày cuối cùng.',
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

      AppToast.showSuccess(context, 'Đã xóa Ngày ${day.dayNumber} thành công.');

      _notifier.loadDetail(token: _effectiveToken);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(context, 'Không thể xóa ngày. Vui lòng thử lại.');
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
      initialSavedPlaces: _notifier.savedPlaces,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      AppToast.showSuccess(context, 'Đã thêm hoạt động mới thành công.');
      _notifier.loadDetail(token: _effectiveToken);
      _loadItinerarySavedPlaces();
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
      initialSavedPlaces: _notifier.savedPlaces,
      authNotifier: widget.authNotifier!,
      repository: _crudRepository,
    );

    if (result == true && mounted) {
      AppToast.showSuccess(context, 'Đã cập nhật hoạt động thành công.');
      _notifier.loadDetail(token: _effectiveToken);
      _loadItinerarySavedPlaces();
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

      AppToast.showSuccess(
        context,
        'Đã xóa hoạt động "${activity.name}" thành công.',
      );

      _notifier.loadDetail(token: _effectiveToken);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context,
        'Không thể xóa hoạt động. Vui lòng thử lại.',
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
      AppToast.showSuccess(context, 'Đã cập nhật thứ tự hoạt động.');
      _notifier.loadDetail(token: _effectiveToken);
    }
  }

  Future<bool> _handleActivityVisited(
    ActivityDetail activity,
    ItineraryDayDetail day,
    bool visited,
  ) async {
    final token = _effectiveToken?.trim();
    if (token == null || token.isEmpty) return false;
    final success = await _notifier.updateActivityVisitedStatus(
      dayId: day.dayId,
      activityId: activity.activityId,
      visited: visited,
      token: token,
      repository: _crudRepository,
    );
    if (!success && mounted) {
      AppToast.showError(
        context,
        'Không thể cập nhật trạng thái đã ghé. Vui lòng thử lại.',
      );
    }
    return success;
  }

  Future<bool> _handleSaveActivityOrder(
    ItineraryDetail itinerary,
    ItineraryDayDetail day,
    List<ReorderActivityItem> items,
  ) async {
    final token = _effectiveToken;
    if (token == null) {
      if (mounted) {
        AppToast.showError(context, 'Vui lòng đăng nhập để sắp xếp hoạt động.');
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
        AppToast.showSuccess(context, 'Đã cập nhật thứ tự hoạt động.');
        _notifier.loadDetail(token: _effectiveToken);
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        AppToast.showError(context, e.message);
      }
      return false;
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Không thể lưu thứ tự hoạt động. Vui lòng thử lại.',
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
      AppToast.showInfo(
        context,
        'Vui lòng đăng nhập để lưu lịch trình.',
        duration: const Duration(seconds: 2),
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
      AppSyncBus.emitItinerarySaved(itinerary.itineraryId, nextSaved);
      if (mounted) {
        AppToast.showInfo(
          context,
          nextSaved ? 'Đã lưu lịch trình' : 'Đã bỏ lưu lịch trình',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Lỗi: $e');
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
      AppToast.showInfo(
        context,
        'Vui lòng đăng nhập để lưu lịch trình yêu thích.',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (isOwner) {
      AppToast.showInfo(
        context,
        'Bạn không thể tự yêu thích lịch trình của mình',
        duration: const Duration(seconds: 2),
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
      AppSyncBus.emitItineraryFavorited(itinerary.itineraryId, nextFav);
      if (mounted) {
        AppToast.showInfo(
          context,
          nextFav ? 'Đã thêm vào yêu thích' : 'Đã bỏ yêu thích lịch trình',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Lỗi: $e');
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
      AppToast.showInfo(
        context,
        'Vui lòng đăng nhập để đánh giá lịch trình.',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (isOwner) {
      AppToast.showInfo(
        context,
        'Bạn không thể tự đánh giá lịch trình của mình',
        duration: const Duration(seconds: 2),
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
                            child: BounceTap.icon(
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
                  BounceTap(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(-1),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Xóa đánh giá'),
                    ),
                  ),
                BounceTap(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                BounceTap(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(selectedScore),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Gửi'),
                  ),
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
        AppSyncBus.emitItineraryRatingChanged(
          itinerary.itineraryId,
          _averageRatingOverride ?? 0.0,
          _ratingCountOverride ?? 0,
        );
        if (mounted) {
          AppToast.showInfo(context, 'Đã xóa đánh giá');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Lỗi: $e');
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
        AppSyncBus.emitItineraryRatingChanged(
          itinerary.itineraryId,
          _averageRatingOverride ?? 0.0,
          _ratingCountOverride ?? 0,
        );
        if (mounted) {
          AppToast.showSuccess(context, 'Đã gửi đánh giá thành công');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Lỗi: $e');
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

        if (itinerary == null) {
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
                leadingWidth: 58,
                titleSpacing: 4,
                title: const Text(
                  'Chi tiết lịch trình',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Center(
                    child: AppHeaderBackButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          _hasSocialChanges
                              ? _buildSocialUpdate(itinerary)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
              body: _buildBody(itinerary, isOwner),
            ),
          );
        }

        final expandedHeight = 265.0;
        final topPadding = MediaQuery.paddingOf(context).top;
        final collapseThreshold = expandedHeight - kToolbarHeight - topPadding - 16;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop && _hasSocialChanges) {
              widget.onSocialUpdate?.call(_buildSocialUpdate(itinerary));
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  final collapsed = notification.metrics.pixels >= collapseThreshold;
                  if (collapsed != _isHeaderCollapsed.value) {
                    _isHeaderCollapsed.value = collapsed;
                  }
                }
                return false;
              },
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isHeaderCollapsed,
                    builder: (context, isCollapsed, _) {
                      return SliverAppBar(
                        pinned: true,
                        expandedHeight: expandedHeight,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E1E1E),
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        leadingWidth: 58,
                        titleSpacing: 4,
                        leading: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Center(
                            child: AppHeaderBackButton(
                              isOverlay: !isCollapsed,
                              onPressed: () {
                                Navigator.of(context).pop(
                                  _hasSocialChanges
                                      ? _buildSocialUpdate(itinerary)
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),
                        title: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: isCollapsed ? 1.0 : 0.0,
                          child: const Text(
                            'Chi tiết lịch trình',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        actions: [
                          if (!isOwner) ...[
                            AppHeaderIconButton(
                              icon: effectiveSaved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border_rounded,
                              tooltip: effectiveSaved
                                  ? 'Bỏ lưu'
                                  : 'Lưu lịch trình',
                              isOverlay: !isCollapsed,
                              isActive: effectiveSaved,
                              onPressed: _isTogglingSave
                                  ? null
                                  : () => _handleToggleSave(itinerary),
                            ),
                            const SizedBox(width: 8),
                            AppHeaderIconButton(
                              icon: effectiveFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border_rounded,
                              tooltip: effectiveFavorited
                                  ? 'Bỏ yêu thích'
                                  : 'Yêu thích',
                              isOverlay: !isCollapsed,
                              isActive: effectiveFavorited,
                              onPressed: _isTogglingFavorite
                                  ? null
                                  : () => _handleToggleFavorite(
                                        itinerary,
                                        isOwner,
                                      ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_isCloning || _isDeleting)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFA3E62),
                                  ),
                                ),
                              ),
                            )
                          else
                            AppHeaderIconButton(
                              icon: Icons.more_horiz_rounded,
                              tooltip: 'Tùy chọn',
                              isOverlay: !isCollapsed,
                              onPressed: () =>
                                  _showMoreActionsSheet(itinerary, isOwner),
                            ),
                          const SizedBox(width: 12),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          background: _buildSliverCoverBackground(itinerary),
                        ),
                      );
                    },
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PinnedTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: const Color(0xFFFA3E62),
                        indicatorWeight: 2.5,
                        labelColor: const Color(0xFFFA3E62),
                        unselectedLabelColor: const Color(0xFF6E6E73),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        tabs: const [
                          Tab(
                            height: 64,
                            child: BounceTap(
                              useSelectionHaptic: true,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline, size: 18),
                                  SizedBox(height: 4),
                                  Text('Tổng quan'),
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            height: 64,
                            child: BounceTap(
                              useSelectionHaptic: true,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_note_outlined, size: 18),
                                  SizedBox(height: 4),
                                  Text('Hoạt động'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: _buildBody(itinerary, isOwner),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ItineraryDetail? itinerary, bool isOwner) {
    if (itinerary != null) {
      return TabBarView(
        controller: _tabController,
        children: [
          _KeepAliveTabWrapper(
            key: const PageStorageKey<String>('keep_alive_overview'),
            child: _buildOverviewTab(itinerary, isOwner),
          ),
          _KeepAliveTabWrapper(
            key: const PageStorageKey<String>('keep_alive_activities'),
            child: _buildActivitiesTab(itinerary, isOwner),
          ),
        ],
      );
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

  // ================= TAB 1: TỔNG QUAN =================
  Widget _buildOverviewTab(ItineraryDetail itinerary, bool isOwner) {
    final showSocialSections =
        (itinerary.status == 'ACTIVE' || itinerary.status == 'PUBLISHED') &&
        itinerary.visibility == 'PUBLIC';

    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([
            _notifier.loadDetail(token: _effectiveToken),
            _loadItinerarySavedPlaces(),
          ]);
        },
        child: CustomScrollView(
          key: const PageStorageKey<String>('itinerary_overview_scroll'),
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
                      BounceTap(
                        child: TextButton(
                          onPressed: () =>
                              _notifier.retry(token: _effectiveToken),
                          child: const Text(
                            'Thử lại',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Khối 1: Giới thiệu lịch trình
            SliverToBoxAdapter(child: _buildOverview(itinerary, isOwner)),
            const SliverToBoxAdapter(child: _FlatSectionDivider()),

            // Khối 2: Địa điểm đã lưu
            SliverToBoxAdapter(
              child: _buildItinerarySavedPlacesSection(itinerary, isOwner),
            ),

            // Khối 3: Bình luận (public & active)
            if (showSocialSections) ...[
              const SliverToBoxAdapter(child: _FlatSectionDivider()),
              SliverToBoxAdapter(
                child: ItineraryCommentsSection(
                  itineraryId: itinerary.itineraryId,
                  token: _effectiveToken,
                  authNotifier: widget.authNotifier,
                ),
              ),
              const SliverToBoxAdapter(child: _FlatSectionDivider()),
              // Khối 4: Đánh giá (public & active)
              SliverToBoxAdapter(
                child: _buildRatingSection(itinerary, isOwner),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  // ================= TAB 2: HOẠT ĐỘNG =================
  Widget _buildActivitiesTab(ItineraryDetail itinerary, bool isOwner) {
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
        key: const PageStorageKey<String>('itinerary_activities_scroll'),
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

          // 1. Day Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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

          // 2. Compact Horizontal Day Selector
          if (itinerary.days.isNotEmpty)
            SliverToBoxAdapter(child: _buildDaySelector(itinerary)),

          // 3. Embedded Itinerary Map Preview Card
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
                    onActivityTap: (act) => _handleViewActivityDetail(act, day),
                    onActivityVisited:
                        isOwner && _effectiveToken?.trim().isNotEmpty == true
                        ? (act, visited) =>
                              _handleActivityVisited(act, day, visited)
                        : null,
                    onActivityComments:
                        !isOwner &&
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
                    onSavePlace: (act) =>
                        _openSavePlaceToMyItinerariesSheet(activity: act),
                  );
                },
              ),
            ),
            if (isOwner && _selectedDayNumber == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                  child: BounceTap(
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
              ),
            if (_selectedDayNumber != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                  child: BounceTap(
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
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Future<void> _openActivityComments(
    int activityId,
    String activityName,
  ) async {
    await AppBottomSheet.show<void>(
      context,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final availableHeight =
            mediaQuery.size.height - mediaQuery.viewInsets.bottom;
        return SizedBox(
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
                    BounceTap.icon(
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ActivityCommentsSection(
                  activityId: activityId,
                  token: _effectiveToken,
                  authNotifier: widget.authNotifier,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) {
      await _notifier.loadDetail(token: _effectiveToken);
    }
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
    return BounceTap(
      useSelectionHaptic: true,
      child: ChoiceChip(
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
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đánh giá ($effectiveRatingCount)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              if (!isOwner && !isGuest)
                BounceTap(
                  child: Material(
                    color: const Color(0xFFFFF0F3),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => _openRatingDialog(itinerary, isOwner),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasUserRating
                                  ? Icons.edit_outlined
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: const Color(0xFFFA3E62),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasUserRating ? 'Sửa đánh giá' : 'Đánh giá ngay',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFA3E62),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBEBEF)),
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
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(width: 14),
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
                      BounceTap(
                        child: TextButton(
                          onPressed: () => _openRatingDialog(itinerary, isOwner),
                          child: const Text('Đánh giá'),
                        ),
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
                      BounceTap(
                        child: InkWell(
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
                      BounceTap(
                        child: OutlinedButton.icon(
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

  void _showMoreActionsSheet(ItineraryDetail itinerary, bool isOwner) {
    AppBottomSheet.showOptions<void>(
      context,
      title: 'Tùy chọn lịch trình',
      options: [
        if (isOwner)
          AppBottomSheetOption(
            icon: Icons.edit_outlined,
            label: 'Chỉnh sửa lịch trình',
            onTap: () => _handleEdit(itinerary),
          ),
        AppBottomSheetOption(
          icon: Icons.copy_all_outlined,
          label: isOwner ? 'Sao chép lịch trình' : 'Sao chép lịch trình này',
          onTap: () => _handleClone(itinerary),
        ),
        AppBottomSheetOption(
          icon: Icons.share_outlined,
          label: 'Chia sẻ lịch trình',
          onTap: () => _handleShare(itinerary),
        ),
        if (isOwner)
          AppBottomSheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Xóa lịch trình',
            isDestructive: true,
            onTap: () => _handleDelete(itinerary),
          ),
      ],
    );
  }

  Widget _buildSliverCoverBackground(ItineraryDetail itinerary) {
    final imageUrl = itinerary.coverImage?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final creatorName =
        (itinerary.creator?.fullName?.trim().isNotEmpty == true)
        ? itinerary.creator!.fullName!.trim()
        : ((itinerary.creator?.username.trim().isNotEmpty == true)
            ? itinerary.creator!.username.trim()
            : 'Traveler');

    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: 'itinerary_card_${itinerary.itineraryId}',
          child: hasImage
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildGradientCoverPlaceholder(),
                )
              : _buildGradientCoverPlaceholder(),
        ),
        // Bottom gradient scrim for readable white title & creator info
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.68),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                itinerary.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Tạo bởi $creatorName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${itinerary.viewCount} lượt xem',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientCoverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFA3E62), Color(0xFFFF7A8F)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.travel_explore_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  Widget _buildOverview(ItineraryDetail itinerary, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giới thiệu lịch trình',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
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
                    BounceTap(
                      enabled: itinerary.creator!.userId != 0,
                      child: InkWell(
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

  String _formatBudget(double budget) {
    if (budget <= 0) return 'Chưa cập nhật';
    final formatted = budget.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$formatted ₫';
  }

  Future<void> _loadItinerarySavedPlaces() async {
    await _notifier.loadSavedPlaces(
      token: _effectiveToken,
      repository: _crudRepository,
    );
  }

  Future<void> _handleRemoveSavedPlace(ItineraryPlace ip) async {
    if (_effectiveToken == null) return;
    final confirmed = await AppDialog.showConfirm(
      context,
      type: AppDialogType.danger,
      title: 'Bỏ lưu địa điểm',
      message:
          'Bạn có chắc chắn muốn bỏ lưu "${ip.place.name}" khỏi lịch trình này? Các hoạt động trong lịch trình sẽ không bị ảnh hưởng.',
      confirmText: 'Bỏ lưu',
      cancelText: 'Hủy',
    );
    if (confirmed != true || !mounted) return;

    try {
      await _crudRepository.removePlaceFromItinerary(
        widget.itineraryId,
        ip.place.placeId,
        token: _effectiveToken!,
      );
      _notifier.removeSavedPlace(ip.place.placeId);
      await _loadItinerarySavedPlaces();
      if (mounted) {
        AppToast.showInfo(
          context,
          'Đã xóa "${ip.place.name}" khỏi danh sách lưu của lịch trình.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          e is ApiException ? e.message : 'Lỗi khi xóa địa điểm',
        );
      }
    }
  }

  Future<void> _showAddPlaceToItineraryDialog() async {
    final auth = widget.authNotifier;
    if (auth == null || !auth.isAuthenticated) {
      AppToast.showError(
        context,
        'Vui lòng đăng nhập để thêm địa điểm vào lịch trình.',
      );
      return;
    }

    final detail = _notifier.itineraryDetail;
    final summary = detail != null
        ? ItinerarySummary(
            itineraryId: detail.itineraryId,
            title: detail.title,
            location: detail.location,
            totalDays: detail.totalDays,
            theme: detail.theme,
            budget: detail.budget,
            visibility: detail.visibility,
            status: detail.status,
            viewCount: 0,
            favoriteCount: detail.favoriteCount,
            ratingCount: detail.ratingCount,
            averageRating: detail.averageRating,
          )
        : null;

    final result = await showAddPlaceToItinerarySheet(
      context,
      authNotifier: auth,
      repository: _crudRepository,
      initialItinerary: summary,
    );

    if (result == true && mounted) {
      _loadItinerarySavedPlaces();
    }
  }

  Future<void> _openSavePlaceToMyItinerariesSheet({
    PlaceSummary? place,
    ActivityDetail? activity,
  }) async {
    final auth = widget.authNotifier;
    if (auth == null || !auth.isAuthenticated) {
      AppToast.showError(
        context,
        'Vui lòng đăng nhập để lưu địa điểm vào lịch trình.',
      );
      return;
    }

    String locationName = '';
    String? address;
    double? lat;
    double? lng;
    int? placeId;
    String? category;
    String? imageUrl;

    if (place != null) {
      locationName = place.name;
      address = place.address;
      lat = place.latitude;
      lng = place.longitude;
      placeId = place.placeId;
      category = place.category;
      imageUrl = place.imageUrl;
    } else if (activity != null) {
      locationName = activity.effectiveLocationName ?? activity.name;
      address = activity.effectiveAddress;
      lat = activity.effectiveLatitude;
      lng = activity.effectiveLongitude;
      placeId = activity.place?.placeId ?? activity.canonicalPlaceId;
      category = activity.place?.category ?? 'Hoạt động';
      imageUrl = activity.effectiveImageUrl;
    }

    if (locationName.isEmpty) return;

    await showSavePlaceToItinerarySheet(
      context,
      authNotifier: auth,
      repository: _crudRepository,
      locationName: locationName,
      address: address,
      latitude: lat,
      longitude: lng,
      canonicalPlaceId: placeId,
      category: category,
      imageUrl: imageUrl,
    );
  }

  List<ItineraryPlace> _getEffectiveSavedPlaces(ItineraryDetail itinerary) {
    if (_notifier.savedPlaces.isNotEmpty) {
      return _notifier.savedPlaces;
    }
    final seenPlaceIds = <int>{};
    final derived = <ItineraryPlace>[];
    for (final day in itinerary.days) {
      for (final act in day.activities) {
        final p = act.place;
        if (p != null && p.placeId > 0 && !seenPlaceIds.contains(p.placeId)) {
          seenPlaceIds.add(p.placeId);
          derived.add(
            ItineraryPlace(
              id: p.placeId,
              itineraryId: itinerary.itineraryId,
              place: p,
            ),
          );
        }
      }
    }
    return derived;
  }

  Widget _buildItinerarySavedPlacesSection(
    ItineraryDetail itinerary,
    bool isOwner,
  ) {
    final savedPlaces = _getEffectiveSavedPlaces(itinerary);
    final isLoading = _notifier.isLoadingSavedPlaces && savedPlaces.isEmpty;
    final error = _notifier.savedPlacesError;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Địa điểm đã lưu (${savedPlaces.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: 8),
                BounceTap(
                  child: Material(
                    color: const Color(0xFFFFF0F3),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _showAddPlaceToItineraryDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_add_outlined,
                              size: 15,
                              color: Color(0xFFFA3E62),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Thêm địa điểm',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFA3E62),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (error != null && savedPlaces.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 36,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  BounceTap(
                    child: TextButton.icon(
                      onPressed: _loadItinerarySavedPlaces,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Thử lại'),
                    ),
                  ),
                ],
              ),
            )
          else if (savedPlaces.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEFEFF4)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 38,
                    color: AppColors.muted.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chưa có địa điểm đã lưu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOwner
                        ? 'Lưu các địa điểm bạn muốn ghé thăm trong chuyến đi này để thuận tiện lên kế hoạch hoạt động.'
                        : 'Chưa có địa điểm nào được lưu trong lịch trình này.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6E6E73),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 12),
                    BounceTap(
                      child: FilledButton.tonalIcon(
                        onPressed: _showAddPlaceToItineraryDialog,
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          size: 16,
                        ),
                        label: const Text('Thêm địa điểm'),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < savedPlaces.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildSavedPlaceCard(savedPlaces[i], isOwner),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSavedPlaceCard(ItineraryPlace ip, bool isOwner) {
    final p = ip.place;
    return BounceTap(
      child: Material(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showPlaceDetailsModal(p),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBEBEF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 64x64 Thumbnail with subtle border
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? Image.network(
                          p.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildSavedPlacePlaceholder(),
                        )
                      : _buildSavedPlacePlaceholder(),
                ),
                const SizedBox(width: 12),

                // Center Info (Title, Category Pill, Pin + Address)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E1E1E),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.category != null &&
                          p.category!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.localizedCategory,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFA3E62),
                            ),
                          ),
                        ),
                      ],
                      if (p.address != null &&
                          p.address!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: Color(0xFF8E8E93),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                p.address!.trim(),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF6E6E73),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Action Button (36x36 rounded square)
                if (isOwner)
                  BounceTap.icon(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: Color(0xFFFA3E62),
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: (val) {
                          if (val == 'view') {
                            _showPlaceDetailsModal(p);
                          } else if (val == 'delete') {
                            _handleRemoveSavedPlace(ip);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 16),
                                SizedBox(width: 8),
                                Expanded(child: Text('Xem chi tiết')),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Xóa khỏi lịch trình',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  BounceTap.icon(
                    child: Tooltip(
                      message: 'Lưu vào lịch trình của tôi',
                      child: Material(
                        color: const Color(0xFFFFF0F3),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () =>
                              _openSavePlaceToMyItinerariesSheet(place: p),
                          borderRadius: BorderRadius.circular(10),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.bookmark_add_outlined,
                              size: 19,
                              color: Color(0xFFFA3E62),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaceDetailsModal(PlaceSummary p) {
    AppBottomSheet.show<void>(
      context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (p.category != null && p.category!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.localizedCategory,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              if (p.address != null && p.address!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.address!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (p.description != null && p.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  p.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: BounceTap(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedPlacePlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.surfaceSoft,
      child: const Center(
        child: Icon(Icons.place, color: AppColors.primary, size: 24),
      ),
    );
  }
}

class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveTabWrapper({super.key, required this.child});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _FlatSectionDivider extends StatelessWidget {
  const _FlatSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
    );
  }
}
