import 'package:flutter/material.dart';

import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/sync/auto_refresh_lifecycle_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/current_user_avatar_button.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../explore/presentation/widgets/itinerary_card.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../data/collection_repository.dart';
import '../collection_notifier.dart';
import '../../../social/data/models/social_state_update.dart';

class CollectionScreen extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final CollectionNotifier? notifier;
  final CollectionRepository? repository;

  const CollectionScreen({
    super.key,
    this.authNotifier,
    this.notifier,
    this.repository,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with
        SingleTickerProviderStateMixin,
        AutoRefreshLifecycleMixin<CollectionScreen> {
  late final CollectionNotifier _notifier;
  late final TabController _tabController;
  final ScrollController _savedScrollController = ScrollController();
  final ScrollController _favoriteScrollController = ScrollController();

  String? get _effectiveToken => widget.authNotifier?.token;

  @override
  Set<SyncDomain> get syncDomains => {
    SyncDomain.collections,
    SyncDomain.itineraries,
  };

  @override
  Duration get syncTtl => const Duration(minutes: 3);

  @override
  Future<void> onRefreshData({bool isBackground = false}) async {
    await Future.wait([
      _notifier.loadInitialSaved(token: _effectiveToken),
      _notifier.loadInitialFavorite(token: _effectiveToken),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _notifier =
        widget.notifier ??
        CollectionNotifier(
          repository: widget.repository ?? CollectionRepository(),
        );

    _tabController = TabController(length: 2, vsync: this);

    _savedScrollController.addListener(_onSavedScroll);
    _favoriteScrollController.addListener(_onFavoriteScroll);
    widget.authNotifier?.addListener(_onAuthChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.loadInitialSaved(token: _effectiveToken);
        _notifier.loadInitialFavorite(token: _effectiveToken);
      }
    });
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  bool _isItineraryOwner(ItinerarySummary itinerary) {
    if (widget.authNotifier?.isAuthenticated != true) return false;
    final currentUsername = widget.authNotifier?.currentUser?['username']
        ?.toString()
        .trim();
    final currentUserId = widget.authNotifier?.currentUser?['userId'] is num
        ? (widget.authNotifier!.currentUser!['userId'] as num).toInt()
        : int.tryParse(
            widget.authNotifier?.currentUser?['userId']?.toString() ?? '',
          );
    final creatorUserId = itinerary.creator?.userId;
    final creatorUsername = itinerary.creator?.username.trim();

    return (currentUserId != null &&
            creatorUserId != null &&
            creatorUserId != 0 &&
            currentUserId == creatorUserId) ||
        (currentUsername != null &&
            creatorUsername != null &&
            creatorUsername.isNotEmpty &&
            creatorUsername.toLowerCase() != 'anonymous' &&
            currentUsername.toLowerCase() == creatorUsername.toLowerCase());
  }

  @override
  void dispose() {
    widget.authNotifier?.removeListener(_onAuthChanged);
    _savedScrollController.removeListener(_onSavedScroll);
    _favoriteScrollController.removeListener(_onFavoriteScroll);
    _savedScrollController.dispose();
    _favoriteScrollController.dispose();
    _tabController.dispose();
    if (widget.notifier == null) {
      _notifier.dispose();
    }
    super.dispose();
  }

  void _onSavedScroll() {
    if (!_savedScrollController.hasClients) return;
    final maxScroll = _savedScrollController.position.maxScrollExtent;
    final currentScroll = _savedScrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _notifier.loadMoreSaved(token: _effectiveToken);
    }
  }

  void _onFavoriteScroll() {
    if (!_favoriteScrollController.hasClients) return;
    final maxScroll = _favoriteScrollController.position.maxScrollExtent;
    final currentScroll = _favoriteScrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _notifier.loadMoreFavorite(token: _effectiveToken);
    }
  }

  Future<void> _handleRemoveSaved(ItinerarySummary item) async {
    try {
      await _notifier.removeSaved(item.itineraryId, token: _effectiveToken);
      AppSyncBus.emitItinerarySaved(item.itineraryId, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã bỏ lưu lịch trình'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể bỏ lưu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveFavorite(ItinerarySummary item) async {
    try {
      await _notifier.removeFavorite(item.itineraryId, token: _effectiveToken);
      AppSyncBus.emitItineraryFavorited(item.itineraryId, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã bỏ yêu thích lịch trình'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể bỏ yêu thích: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openDetail(
    ItinerarySummary item, {
    bool? isSaved,
    bool? isFavorited,
  }) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => ItineraryDetailScreen(
          itineraryId: item.itineraryId,
          initialSummary: item,
          initialIsSaved: isSaved,
          initialIsFavorited: isFavorited,
          token: widget.authNotifier?.token,
          authNotifier: widget.authNotifier,
          onSocialUpdate: (update) {
            _notifier.applySocialUpdate(update);
          },
        ),
      ),
    );

    if (result is SocialStateUpdate && mounted) {
      _notifier.applySocialUpdate(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Bộ sưu tập'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.authNotifier?.isAuthenticated == true)
            CurrentUserAvatarButton(
              avatarUrl: widget.authNotifier?.currentUser?['avatar']
                  ?.toString(),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProfileScreen(authNotifier: widget.authNotifier!),
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.hairlineSoft, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Đã lưu'),
                Tab(text: 'Yêu thích'),
              ],
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [_buildSavedTab(), _buildFavoriteTab()],
          );
        },
      ),
    );
  }

  Widget _buildSavedTab() {
    final state = _notifier.savedState;

    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return AppErrorState(
        title: 'Lỗi tải lịch trình đã lưu',
        message: state.error!,
        onRetry: () => _notifier.loadInitialSaved(token: _effectiveToken),
      );
    }

    if (state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Chưa có lịch trình đã lưu',
        message: 'Lịch trình bạn lưu sẽ xuất hiện tại đây để tiện xem lại sau.',
        actionText: 'Tải lại',
        onActionPressed: () =>
            _notifier.loadInitialSaved(token: _effectiveToken),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await _notifier.refreshSaved(token: _effectiveToken);
        recordRefreshedNow();
      },
      child: ListView.builder(
        key: const PageStorageKey<String>('saved_collection_list'),
        controller: _savedScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
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

          final item = state.items[index];
          final isOwner = _isItineraryOwner(item);
          return ItineraryCard(
            itinerary: item,
            actionIcon: isOwner ? null : Icons.bookmark,
            actionIconColor: AppColors.savedActive,
            onActionTap: isOwner ? null : () => _handleRemoveSaved(item),
            showFavorite: !isOwner,
            onTap: () => _openDetail(item, isSaved: true),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteTab() {
    final state = _notifier.favoriteState;

    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return AppErrorState(
        title: 'Lỗi tải lịch trình yêu thích',
        message: state.error!,
        onRetry: () => _notifier.loadInitialFavorite(token: _effectiveToken),
      );
    }

    if (state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Chưa có lịch trình yêu thích',
        message: 'Lịch trình bạn yêu thích sẽ xuất hiện tại đây.',
        actionText: 'Tải lại',
        onActionPressed: () =>
            _notifier.loadInitialFavorite(token: _effectiveToken),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await _notifier.refreshFavorite(token: _effectiveToken);
        recordRefreshedNow();
      },
      child: ListView.builder(
        key: const PageStorageKey<String>('favorite_collection_list'),
        controller: _favoriteScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
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

          final item = state.items[index];
          final isOwner = _isItineraryOwner(item);
          return ItineraryCard(
            itinerary: item,
            actionIcon: isOwner ? null : Icons.favorite,
            actionIconColor: Colors.redAccent,
            onActionTap: isOwner ? null : () => _handleRemoveFavorite(item),
            showFavorite: !isOwner,
            onTap: () => _openDetail(item, isFavorited: true),
          );
        },
      ),
    );
  }
}
