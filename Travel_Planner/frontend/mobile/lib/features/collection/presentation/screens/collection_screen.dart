import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../explore/presentation/widgets/itinerary_card.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
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
    with SingleTickerProviderStateMixin {
  late final CollectionNotifier _notifier;
  late final TabController _tabController;
  final ScrollController _savedScrollController = ScrollController();
  final ScrollController _favoriteScrollController = ScrollController();

  String? get _effectiveToken => widget.authNotifier?.token;

  @override
  void initState() {
    super.initState();
    _notifier = widget.notifier ??
        CollectionNotifier(
          repository: widget.repository ?? CollectionRepository(),
        );

    _tabController = TabController(length: 2, vsync: this);

    _savedScrollController.addListener(_onSavedScroll);
    _favoriteScrollController.addListener(_onFavoriteScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.loadInitialSaved(token: _effectiveToken);
        _notifier.loadInitialFavorite(token: _effectiveToken);
      }
    });
  }

  @override
  void dispose() {
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
        title: const Text(
          'Bộ sưu tập',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.hairlineSoft, width: 0.5),
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
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.bookmark_outline, size: 20),
                  text: 'Đã lưu',
                ),
                Tab(
                  icon: Icon(Icons.favorite_outline, size: 20),
                  text: 'Yêu thích',
                ),
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
            children: [
              _buildSavedTab(),
              _buildFavoriteTab(),
            ],
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
        onActionPressed: () => _notifier.loadInitialSaved(token: _effectiveToken),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _notifier.refreshSaved(token: _effectiveToken),
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
          return ItineraryCard(
            itinerary: item,
            actionIcon: Icons.bookmark,
            actionIconColor: AppColors.savedActive,
            onActionTap: () => _handleRemoveSaved(item),
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
        onActionPressed: () => _notifier.loadInitialFavorite(token: _effectiveToken),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _notifier.refreshFavorite(token: _effectiveToken),
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
          return ItineraryCard(
            itinerary: item,
            actionIcon: Icons.favorite,
            actionIconColor: Colors.redAccent,
            onActionTap: () => _handleRemoveFavorite(item),
            onTap: () => _openDetail(item, isFavorited: true),
          );
        },
      ),
    );
  }
}

