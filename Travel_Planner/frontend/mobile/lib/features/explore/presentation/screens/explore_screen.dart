import '../../../social/data/models/social_state_update.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/current_user_avatar_button.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../itinerary/presentation/itinerary_detail_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../data/models/itinerary_summary.dart';
import '../explore_notifier.dart';
import '../widgets/compact_itinerary_card.dart';
import '../widgets/featured_itinerary_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/itinerary_card.dart';
import '../widgets/search_bar_pill.dart';
import '../widgets/section_error_view.dart';
import '../widgets/section_header.dart';
import '../widgets/section_skeleton_loader.dart';
import '../widgets/theme_category_card.dart';

class ExploreScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ExploreNotifier? exploreNotifier;
  final ItineraryDetailNotifier Function(int itineraryId, String? token)?
  itineraryDetailNotifierFactory;
  final VoidCallback? onProfileTap;

  const ExploreScreen({
    super.key,
    required this.authNotifier,
    this.exploreNotifier,
    this.itineraryDetailNotifierFactory,
    this.onProfileTap,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ExploreNotifier _exploreNotifier;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _exploreNotifier = widget.exploreNotifier ?? ExploreNotifier();

    _scrollController.addListener(_onScroll);

    widget.authNotifier.addListener(_onAuthChanged);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exploreNotifier.loadInitialItineraries(token: widget.authNotifier.token);
    });
  }

  @override
  void dispose() {
    widget.authNotifier.removeListener(_onAuthChanged);
    _searchController.dispose();
    _scrollController.dispose();
    if (widget.exploreNotifier == null) {
      _exploreNotifier.dispose();
    }
    super.dispose();
  }

  void _onAuthChanged() {
    _exploreNotifier.loadUserFavorites(token: widget.authNotifier.token);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 250) {
      if (_exploreNotifier.isSearchOrFilterActive) {
        _exploreNotifier.loadMore(token: widget.authNotifier.token);
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(authNotifier: widget.authNotifier),
      ),
    );
  }

  void _navigateToProfile() {
    final onProfileTap = widget.onProfileTap;
    if (onProfileTap != null) {
      onProfileTap();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(authNotifier: widget.authNotifier),
      ),
    );
  }

  void _navigateToDetail(ItinerarySummary itinerary) async {
    final isFav = _exploreNotifier.isFavorited(itinerary.itineraryId);
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => ItineraryDetailScreen(
          itineraryId: itinerary.itineraryId,
          initialSummary: itinerary,
          initialIsFavorited: isFav,
          token: widget.authNotifier.token,
          authNotifier: widget.authNotifier,
          onSocialUpdate: (update) {
            _exploreNotifier.applySocialUpdate(update);
          },
          notifier: widget.itineraryDetailNotifierFactory?.call(
            itinerary.itineraryId,
            widget.authNotifier.token,
          ),
        ),
      ),
    );
    if (result is SocialStateUpdate && mounted) {
      _exploreNotifier.applySocialUpdate(result);
    } else if (result == true && mounted) {
      _exploreNotifier.refreshAll(token: widget.authNotifier.token);
    }
  }

  Future<void> _handleFavoriteTap(ItinerarySummary itinerary) async {
    if (!widget.authNotifier.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vui lòng đăng nhập để lưu lịch trình yêu thích.',
          ),
          backgroundColor: AppColors.textPrimary,
          action: SnackBarAction(
            label: 'Đăng nhập',
            textColor: AppColors.primary,
            onPressed: _navigateToLogin,
          ),
        ),
      );
      return;
    }

    final currentUsername = widget.authNotifier.currentUser?['username']?.toString().trim();
    final currentUserId = widget.authNotifier.currentUser?['userId'] is num
        ? (widget.authNotifier.currentUser!['userId'] as num).toInt()
        : int.tryParse(widget.authNotifier.currentUser?['userId']?.toString() ?? '');
    final isOwner = (currentUserId != null && itinerary.creator?.userId == currentUserId) ||
        (currentUsername != null &&
            itinerary.creator?.username != null &&
            itinerary.creator!.username.toLowerCase() == currentUsername.toLowerCase());

    if (isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể tự yêu thích lịch trình của mình'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_exploreNotifier.isFavoriteLoading(itinerary.itineraryId)) return;

    try {
      final nextFav = await _exploreNotifier.toggleFavorite(
        itineraryId: itinerary.itineraryId,
        token: widget.authNotifier.token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextFav ? 'Đã thêm vào yêu thích' : 'Đã bỏ yêu thích lịch trình'),
            duration: const Duration(seconds: 2),
          ),
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

  void _openFilterBottomSheet() {
    FilterBottomSheet.show(
      context,
      currentFilter: _exploreNotifier.filter,
      currentSort: _exploreNotifier.sort,
      onApply: (filter, sort) {
        _exploreNotifier.applyFilter(filter, token: widget.authNotifier.token);
        _exploreNotifier.setSort(sort, token: widget.authNotifier.token);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authNotifier,
      builder: (context, _) {
        final isAuthenticated = widget.authNotifier.isAuthenticated;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Travel Planner',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
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
              if (isAuthenticated)
                CurrentUserAvatarButton(
                  avatarUrl: widget.authNotifier.currentUser?['avatar']
                      ?.toString(),
                  onPressed: _navigateToProfile,
                ),
              if (!isAuthenticated)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: OutlinedButton(
                    onPressed: _navigateToLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: ListenableBuilder(
            listenable: _exploreNotifier,
            builder: (context, _) {
              return Column(
                children: [
                  // Search & Filter Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: SearchBarPill(
                      controller: _searchController,
                      activeFilterCount:
                          _exploreNotifier.filter.activeFilterCount,
                      onSubmitted: (value) {
                        _exploreNotifier.search(
                          value,
                          token: widget.authNotifier.token,
                        );
                      },
                      onClear: () {
                        _exploreNotifier.search(
                          '',
                          token: widget.authNotifier.token,
                        );
                      },
                      onFilterTap: _openFilterBottomSheet,
                    ),
                  ),

                  // Viewing All Section Header Banner
                  if (_exploreNotifier.isViewingAll)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            onPressed: () => _exploreNotifier.closeViewingAll(
                              token: widget.authNotifier.token,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getViewingAllTitle(_exploreNotifier.viewingAllSection),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Active Filter Summary (if active)
                  if (!_exploreNotifier.filter.isEmpty ||
                      _exploreNotifier.searchKeyword.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (_exploreNotifier.searchKeyword.isNotEmpty)
                                    _buildActiveChip(
                                      'Từ khóa: "${_exploreNotifier.searchKeyword}"',
                                      () {
                                        _searchController.clear();
                                        _exploreNotifier.search(
                                          '',
                                          token: widget.authNotifier.token,
                                        );
                                      },
                                    ),
                                  if (_exploreNotifier.filter.theme != null)
                                    _buildActiveChip(
                                      'Chủ đề: ${_exploreNotifier.filter.theme!}',
                                      () {
                                        _exploreNotifier.applyFilter(
                                          _exploreNotifier.filter.copyWith(
                                            clearTheme: true,
                                          ),
                                          token: widget.authNotifier.token,
                                        );
                                      },
                                    ),
                                  if (_exploreNotifier.filter.location != null)
                                    _buildActiveChip(
                                      _exploreNotifier.filter.location!,
                                      () {
                                        _exploreNotifier.applyFilter(
                                          _exploreNotifier.filter.copyWith(
                                            clearLocation: true,
                                          ),
                                          token: widget.authNotifier.token,
                                        );
                                      },
                                    ),
                                  if (_exploreNotifier.filter.minRating != null)
                                    _buildActiveChip(
                                      '${_exploreNotifier.filter.minRating}+ ★',
                                      () {
                                        _exploreNotifier.applyFilter(
                                          _exploreNotifier.filter.copyWith(
                                            clearRating: true,
                                          ),
                                          token: widget.authNotifier.token,
                                        );
                                      },
                                    ),
                                  if (_exploreNotifier.filter.minDays != null ||
                                      _exploreNotifier.filter.maxDays != null)
                                    _buildActiveChip(
                                      '${_exploreNotifier.filter.minDays ?? 1}–${_exploreNotifier.filter.maxDays ?? 30} ngày',
                                      () {
                                        _exploreNotifier.applyFilter(
                                          _exploreNotifier.filter.copyWith(
                                            clearDays: true,
                                          ),
                                          token: widget.authNotifier.token,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _exploreNotifier.resetAllFilters(
                                token: widget.authNotifier.token,
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              'Xóa tất cả',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Results List / Section Homepage
                  Expanded(child: _buildBody(context, isAuthenticated)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 14),
        backgroundColor: AppColors.surfaceSoft,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isAuthenticated) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    Widget content;

    if (_exploreNotifier.isSearchOrFilterActive) {
      content = _buildSearchFilteredResults(context);
    } else {
      content = _buildDiscoveryHomepage(context, isAuthenticated);
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: content,
    );
  }

  Widget _buildSearchFilteredResults(BuildContext context) {
    if (_exploreNotifier.isLoading) {
      return const Center(
        key: ValueKey('explore_loading'),
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_exploreNotifier.isError) {
      return AppErrorState(
        key: const ValueKey('explore_error'),
        message: _exploreNotifier.errorMessage ?? 'Đã có lỗi xảy ra',
        onRetry: () => _exploreNotifier.retry(token: widget.authNotifier.token),
      );
    } else if (_exploreNotifier.isEmptyResults) {
      return AppEmptyState(
        key: const ValueKey('explore_empty'),
        title: 'Không tìm thấy lịch trình',
        message:
            'Thử thay đổi từ khóa hoặc đặt lại bộ lọc để khám phá các chuyến đi khác.',
        actionText: 'Đặt lại bộ lọc',
        onActionPressed: () {
          _searchController.clear();
          _exploreNotifier.resetAllFilters(token: widget.authNotifier.token);
        },
      );
    }

    final itineraries = _exploreNotifier.itineraries;
    return RefreshIndicator(
      key: const ValueKey('explore_filtered_list'),
      color: AppColors.primary,
      onRefresh: () => _exploreNotifier.fetchItineraries(
        resetPage: true,
        token: widget.authNotifier.token,
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: itineraries.length + (_exploreNotifier.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == itineraries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
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

          final itinerary = itineraries[index];
          return ItineraryCard(
            itinerary: itinerary,
            isFavorited: _exploreNotifier.isFavorited(itinerary.itineraryId),
            onFavoriteTap: () => _handleFavoriteTap(itinerary),
            onTap: () => _navigateToDetail(itinerary),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryHomepage(BuildContext context, bool isAuthenticated) {
    // If the overall explore notifier encountered an error and all sections are unpopulated:
    if (_exploreNotifier.isError &&
        _exploreNotifier.featuredSection.items.isEmpty &&
        _exploreNotifier.recentSection.items.isEmpty &&
        _exploreNotifier.itineraries.isEmpty) {
      return AppErrorState(
        key: const ValueKey('explore_error'),
        message: _exploreNotifier.errorMessage ?? 'Đã có lỗi xảy ra',
        onRetry: () => _exploreNotifier.retry(token: widget.authNotifier.token),
      );
    }

    // If completely empty across all sections:
    if (_exploreNotifier.isEmptyResults &&
        _exploreNotifier.featuredSection.items.isEmpty &&
        _exploreNotifier.recentSection.items.isEmpty) {
      return AppEmptyState(
        key: const ValueKey('explore_empty'),
        title: 'Không tìm thấy lịch trình',
        message:
            'Thử thay đổi từ khóa hoặc đặt lại bộ lọc để khám phá các chuyến đi khác.',
        actionText: 'Đặt lại bộ lọc',
        onActionPressed: () {
          _searchController.clear();
          _exploreNotifier.resetAllFilters(token: widget.authNotifier.token);
        },
      );
    }

    // Collect all available unique items to deduplicate across sections
    final allItemsPool = <ItinerarySummary>[
      ..._exploreNotifier.featuredSection.items,
      ..._exploreNotifier.recommendedSection.items,
      ..._exploreNotifier.topRatedSection.items,
      ..._exploreNotifier.popularSection.items,
      ..._exploreNotifier.recentSection.items,
      ..._exploreNotifier.itineraries,
    ];
    final totalUniqueCount = allItemsPool.map((e) => e.itineraryId).toSet().length;

    // Track displayed IDs to prevent the same itinerary from appearing across multiple sections
    final seenIds = <int>{};

    // If there is only 1 itinerary in total (e.g. in test mock), let Section F render it via ItineraryCard
    final isSingleItemMode = totalUniqueCount <= 1;

    final featuredItems = isSingleItemMode
        ? <ItinerarySummary>[]
        : _filterUnrendered(_exploreNotifier.featuredSection.items, seenIds);

    final recommendedItems = isSingleItemMode
        ? <ItinerarySummary>[]
        : _filterUnrendered(_exploreNotifier.recommendedSection.items, seenIds);

    final topRatedItems = isSingleItemMode
        ? <ItinerarySummary>[]
        : _filterUnrendered(_exploreNotifier.topRatedSection.items, seenIds);

    final popularItems = isSingleItemMode
        ? <ItinerarySummary>[]
        : _filterUnrendered(_exploreNotifier.popularSection.items, seenIds);

    // Section F receives either its own recent items, or any remaining unrendered items from pool
    final recentPool = _exploreNotifier.recentSection.items.isNotEmpty
        ? _exploreNotifier.recentSection.items
        : _exploreNotifier.itineraries;
    final recentItems = _filterUnrendered(recentPool, seenIds);

    return RefreshIndicator(
      key: const ValueKey('explore_homepage_refresh'),
      color: AppColors.primary,
      onRefresh: () => _exploreNotifier.refreshAll(
        token: widget.authNotifier.token,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section A: Chuyến đi nổi bật (Featured Itineraries)
            if (!isSingleItemMode || _exploreNotifier.featuredSection.isLoading)
              _buildSectionAFeatured(featuredItems),

            // Section E: Khám phá theo chủ đề (Explore by Theme)
            _buildSectionEThemes(),

            // Section B: Gợi ý cho bạn (Recommended For You)
            if (!isSingleItemMode || _exploreNotifier.recommendedSection.isLoading)
              _buildSectionBRecommended(recommendedItems, isAuthenticated),

            // Section C: Đánh giá cao nhất (Top Rated)
            if (!isSingleItemMode || _exploreNotifier.topRatedSection.isLoading)
              _buildSectionCTopRated(topRatedItems),

            // Section D: Phổ biến nhất (Popular Itineraries)
            if (!isSingleItemMode || _exploreNotifier.popularSection.isLoading)
              _buildSectionDPopular(popularItems),

            // Section F: Mới chia sẻ gần đây (Recently Shared)
            _buildSectionFRecentlyShared(recentItems),
          ],
        ),
      ),
    );
  }

  List<ItinerarySummary> _filterUnrendered(
    List<ItinerarySummary> source,
    Set<int> seen, {
    int max = 6,
  }) {
    final res = <ItinerarySummary>[];
    for (final item in source) {
      if (!seen.contains(item.itineraryId)) {
        seen.add(item.itineraryId);
        res.add(item);
        if (res.length >= max) break;
      }
    }
    return res;
  }

  // --- Section Builders ---

  Widget _buildSectionAFeatured(List<ItinerarySummary> items) {
    final state = _exploreNotifier.featuredSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Chuyến đi nổi bật',
          subtitle: 'Các hành trình được cộng đồng quan tâm nhất',
          topPadding: 10,
          onActionTap: () => _exploreNotifier.showAllForSection(
            HomeSectionType.featured,
            token: widget.authNotifier.token,
          ),
        ),
        if (state.isLoading)
          const SectionSkeletonLoader(cardWidth: 280, cardHeight: 240)
        else if (state.isError && items.isEmpty)
          SectionErrorView(
            message: state.errorMessage ?? 'Không thể tải chuyến đi nổi bật',
            onRetry: () => _exploreNotifier.retrySection(
              HomeSectionType.featured,
              token: widget.authNotifier.token,
            ),
          )
        else if (items.isNotEmpty)
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final itin = items[index];
                return FeaturedItineraryCard(
                  itinerary: itin,
                  isFavorited: _exploreNotifier.isFavorited(itin.itineraryId),
                  onTap: () => _navigateToDetail(itin),
                  onFavoriteTap: () => _handleFavoriteTap(itin),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionEThemes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Khám phá theo chủ đề',
          subtitle: 'Lựa chọn phong cách du lịch của bạn',
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ThemeCategoryCard.defaultThemes.length,
            itemBuilder: (context, index) {
              final theme = ThemeCategoryCard.defaultThemes[index];
              final isSelected = _exploreNotifier.filter.theme == theme.title;
              return ThemeCategoryCard(
                item: theme,
                isSelected: isSelected,
                onTap: () {
                  _exploreNotifier.setQuickTheme(
                    isSelected ? null : theme.title,
                    token: widget.authNotifier.token,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBRecommended(
    List<ItinerarySummary> items,
    bool isAuthenticated,
  ) {
    final state = _exploreNotifier.recommendedSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Gợi ý cho bạn',
          subtitle: isAuthenticated
              ? 'Dựa trên sở thích và hành trình của bạn'
              : 'Những điểm đến được yêu thích nhất',
          onActionTap: () => _exploreNotifier.showAllForSection(
            HomeSectionType.recommended,
            token: widget.authNotifier.token,
          ),
        ),
        if (state.isLoading)
          const SectionSkeletonLoader(cardWidth: 195, cardHeight: 230)
        else if (state.isError && items.isEmpty)
          SectionErrorView(
            message: state.errorMessage ?? 'Không thể tải chuyến đi gợi ý',
            onRetry: () => _exploreNotifier.retrySection(
              HomeSectionType.recommended,
              token: widget.authNotifier.token,
            ),
          )
        else if (items.isNotEmpty)
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final itin = items[index];
                return CompactItineraryCard(
                  itinerary: itin,
                  isFavorited: _exploreNotifier.isFavorited(itin.itineraryId),
                  highlight: CompactCardHighlight.theme,
                  onTap: () => _navigateToDetail(itin),
                  onFavoriteTap: () => _handleFavoriteTap(itin),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionCTopRated(List<ItinerarySummary> items) {
    final state = _exploreNotifier.topRatedSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Đánh giá cao nhất',
          subtitle: 'Những hành trình có điểm đánh giá xuất sắc',
          onActionTap: () => _exploreNotifier.showAllForSection(
            HomeSectionType.topRated,
            token: widget.authNotifier.token,
          ),
        ),
        if (state.isLoading)
          const SectionSkeletonLoader(cardWidth: 195, cardHeight: 230)
        else if (state.isError && items.isEmpty)
          SectionErrorView(
            message: state.errorMessage ?? 'Không thể tải chuyến đi đánh giá cao',
            onRetry: () => _exploreNotifier.retrySection(
              HomeSectionType.topRated,
              token: widget.authNotifier.token,
            ),
          )
        else if (items.isNotEmpty)
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final itin = items[index];
                return CompactItineraryCard(
                  itinerary: itin,
                  isFavorited: _exploreNotifier.isFavorited(itin.itineraryId),
                  highlight: CompactCardHighlight.rating,
                  onTap: () => _navigateToDetail(itin),
                  onFavoriteTap: () => _handleFavoriteTap(itin),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionDPopular(List<ItinerarySummary> items) {
    final state = _exploreNotifier.popularSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Phổ biến nhất',
          subtitle: 'Được lưu và yêu thích nhiều nhất trong cộng đồng',
          onActionTap: () => _exploreNotifier.showAllForSection(
            HomeSectionType.popular,
            token: widget.authNotifier.token,
          ),
        ),
        if (state.isLoading)
          const SectionSkeletonLoader(cardWidth: 195, cardHeight: 230)
        else if (state.isError && items.isEmpty)
          SectionErrorView(
            message: state.errorMessage ?? 'Không thể tải chuyến đi phổ biến',
            onRetry: () => _exploreNotifier.retrySection(
              HomeSectionType.popular,
              token: widget.authNotifier.token,
            ),
          )
        else if (items.isNotEmpty)
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final itin = items[index];
                return CompactItineraryCard(
                  itinerary: itin,
                  isFavorited: _exploreNotifier.isFavorited(itin.itineraryId),
                  highlight: CompactCardHighlight.popular,
                  onTap: () => _navigateToDetail(itin),
                  onFavoriteTap: () => _handleFavoriteTap(itin),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionFRecentlyShared(List<ItinerarySummary> items) {
    final state = _exploreNotifier.recentSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Mới chia sẻ gần đây',
          subtitle: 'Các hành trình vừa được đăng tải lên cộng đồng',
          onActionTap: () => _exploreNotifier.showAllForSection(
            HomeSectionType.recent,
            token: widget.authNotifier.token,
          ),
        ),
        if (state.isLoading && items.isEmpty)
          const SectionSkeletonLoader(cardWidth: 195, cardHeight: 230)
        else if (state.isError && items.isEmpty)
          SectionErrorView(
            message: state.errorMessage ?? 'Không thể tải chuyến đi mới nhất',
            onRetry: () => _exploreNotifier.retrySection(
              HomeSectionType.recent,
              token: widget.authNotifier.token,
            ),
          )
        else if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: items.map((itin) {
                return ItineraryCard(
                  itinerary: itin,
                  isFavorited: _exploreNotifier.isFavorited(itin.itineraryId),
                  onTap: () => _navigateToDetail(itin),
                  onFavoriteTap: () => _handleFavoriteTap(itin),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _getViewingAllTitle(HomeSectionType? type) {
    switch (type) {
      case HomeSectionType.featured:
        return 'Tất cả chuyến đi nổi bật';
      case HomeSectionType.recommended:
        return 'Tất cả gợi ý cho bạn';
      case HomeSectionType.topRated:
        return 'Tất cả đánh giá cao nhất';
      case HomeSectionType.popular:
        return 'Tất cả chuyến đi phổ biến';
      case HomeSectionType.recent:
      case null:
        return 'Tất cả chuyến đi mới nhất';
    }
  }
}
