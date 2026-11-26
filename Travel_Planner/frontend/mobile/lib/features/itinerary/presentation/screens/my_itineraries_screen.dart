import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/sync/auto_refresh_lifecycle_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_header_button.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/current_user_avatar_button.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/itinerary_crud_repository.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../messaging/presentation/widgets/share_bottom_sheet.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../my_itineraries_notifier.dart';
import '../widgets/delete_itinerary_dialog.dart';
import '../widgets/my_itinerary_card.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'create_itinerary_screen.dart';
import 'edit_itinerary_screen.dart';
import 'itinerary_detail_screen.dart';

class MyItinerariesScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MyItinerariesNotifier? notifier;
  final ItineraryCrudRepository? repository;

  const MyItinerariesScreen({
    super.key,
    required this.authNotifier,
    this.notifier,
    this.repository,
  });

  @override
  State<MyItinerariesScreen> createState() => _MyItinerariesScreenState();
}

class _MyItinerariesScreenState extends State<MyItinerariesScreen>
    with AutoRefreshLifecycleMixin<MyItinerariesScreen> {
  late final MyItinerariesNotifier _notifier;
  late final ItineraryCrudRepository _repository;
  final ScrollController _scrollController = ScrollController();

  @override
  Set<SyncDomain> get syncDomains => {SyncDomain.itineraries};

  @override
  Duration get syncTtl => const Duration(minutes: 3);

  @override
  Future<void> onRefreshData({bool isBackground = false}) async {
    await _notifier.refresh(token: widget.authNotifier.token);
  }

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        widget.notifier?.repository ??
        ItineraryCrudRepository();
    _notifier =
        widget.notifier ?? MyItinerariesNotifier(repository: _repository);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.loadInitialItineraries(token: widget.authNotifier.token);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (widget.notifier == null) {
      _notifier.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 250) {
      _notifier.loadMore(token: widget.authNotifier.token);
    }
  }

  Future<void> _navigateToCreateScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            CreateItineraryScreen(authNotifier: widget.authNotifier),
      ),
    );
    if (result == true && mounted) {
      _notifier.refresh(token: widget.authNotifier.token);
    }
  }

  Future<void> _handleEdit(ItinerarySummary item) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => EditItineraryScreen.fromSummary(
          item,
          authNotifier: widget.authNotifier,
          repository: _repository,
        ),
      ),
    );

    if (result != null && mounted) {
      _notifier.refresh(token: widget.authNotifier.token);
    }
  }

  Future<void> _handleDelete(ItinerarySummary item) async {
    final confirmed = await showDeleteItineraryConfirmationDialog(
      context,
      itineraryTitle: item.title,
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repository.deleteItinerary(
        item.itineraryId,
        token: widget.authNotifier.token,
      );
      AppSyncBus.emitItineraryDeleted(item.itineraryId);

      if (!mounted) return;

      AppToast.showSuccess(context, 'Đã xóa lịch trình thành công.');

      _notifier.refresh(token: widget.authNotifier.token);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(context, 'Không thể xóa lịch trình. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Lịch trình của tôi'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          CurrentUserAvatarButton(
            avatarUrl: widget.authNotifier.currentUser?['avatar']?.toString(),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ProfileScreen(authNotifier: widget.authNotifier),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.hairlineSoft),
        ),
      ),
      floatingActionButton: BounceTap(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFA3E62).withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'my_itineraries_fab',
            key: const Key('fab_create_itinerary'),
            onPressed: _navigateToCreateScreen,
            backgroundColor: const Color(0xFFFA3E62),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Tạo lịch trình',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          _buildFilterBar(),

          // Main Content
          Expanded(
            child: ListenableBuilder(
              listenable: _notifier,
              builder: (context, _) {
                if ((_notifier.status == MyItinerariesStatus.initial ||
                        _notifier.isLoading) &&
                    _notifier.itineraries.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (_notifier.isError && _notifier.itineraries.isEmpty) {
                  return AppErrorState(
                    message:
                        _notifier.errorMessage ??
                        'Không thể tải danh sách lịch trình của bạn.',
                    onRetry: () => _notifier.fetchItineraries(
                      resetPage: true,
                      token: widget.authNotifier.token,
                    ),
                  );
                }

                if (_notifier.isEmptyResults) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await _notifier.refresh(token: widget.authNotifier.token);
                      recordRefreshedNow();
                    },
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.only(top: 80),
                        child: AppEmptyState(
                          title: 'Chưa có lịch trình nào',
                          message: 'Bạn chưa tạo lịch trình nào hoặc không có lịch trình nào phù hợp với bộ lọc.',
                          icon: Icons.map_outlined,
                          actionText: 'Tạo lịch trình ngay',
                          onActionPressed: _navigateToCreateScreen,
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await _notifier.refresh(token: widget.authNotifier.token);
                    recordRefreshedNow();
                  },
                  color: AppColors.primary,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 88),
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 110,
                      endIndent: 16,
                      color: Color(0xFFF0F0F5),
                    ),
                    itemCount:
                        _notifier.itineraries.length +
                        (_notifier.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _notifier.itineraries.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }

                      final item = _notifier.itineraries[index];
                      return MyItineraryCard(
                        itinerary: item,
                        onTap: () async {
                          final result = await Navigator.of(context)
                              .push<dynamic>(
                                MaterialPageRoute<dynamic>(
                                  builder: (_) => ItineraryDetailScreen(
                                    itineraryId: item.itineraryId,
                                    initialSummary: item,
                                    isOwner: true,
                                    token: widget.authNotifier.token,
                                    authNotifier: widget.authNotifier,
                                    crudRepository: _repository,
                                  ),
                                ),
                              );
                          if (result == true && mounted) {
                            _notifier.refresh(token: widget.authNotifier.token);
                          }
                        },
                        onShare: () {
                          ShareBottomSheet.show(
                            context,
                            targetType: 'ITINERARY',
                            targetId: item.itineraryId,
                            title: item.title,
                            coverImage: item.coverImage,
                            subtitle: item.location.isNotEmpty
                                ? item.location
                                : '${item.totalDays} ngày',
                            authNotifier: widget.authNotifier,
                          );
                        },
                        onEdit: () => _handleEdit(item),
                        onDelete: () => _handleDelete(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final isAll =
            _notifier.statusFilter == null &&
            _notifier.visibilityFilter == null;
        final isPublic = _notifier.visibilityFilter == 'PUBLIC';
        final isPrivate = _notifier.visibilityFilter == 'PRIVATE';

        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterChip(
                  label: 'Tất cả',
                  selected: isAll,
                  onSelected: () {
                    _notifier.setStatusFilter(
                      null,
                      token: widget.authNotifier.token,
                    );
                    _notifier.setVisibilityFilter(
                      null,
                      token: widget.authNotifier.token,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Công khai',
                  selected: isPublic,
                  onSelected: () {
                    _notifier.setStatusFilter(
                      null,
                      token: widget.authNotifier.token,
                    );
                    _notifier.setVisibilityFilter(
                      'PUBLIC',
                      token: widget.authNotifier.token,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Riêng tư',
                  selected: isPrivate,
                  onSelected: () {
                    _notifier.setStatusFilter(
                      null,
                      token: widget.authNotifier.token,
                    );
                    _notifier.setVisibilityFilter(
                      'PRIVATE',
                      token: widget.authNotifier.token,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return BounceTap(
      useSelectionHaptic: true,
      child: Material(
        color: selected ? const Color(0xFFFFF0F3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFA3E62)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFFA3E62)
                    : const Color(0xFF1E1E1E),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
