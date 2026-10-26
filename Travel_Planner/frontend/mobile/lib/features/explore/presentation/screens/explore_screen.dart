import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../itinerary/presentation/itinerary_detail_notifier.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../itinerary/presentation/screens/my_itineraries_screen.dart';
import '../explore_notifier.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/itinerary_card.dart';
import '../widgets/search_bar_pill.dart';

class ExploreScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ExploreNotifier? exploreNotifier;
  final ItineraryDetailNotifier Function(int itineraryId, String? token)?
  itineraryDetailNotifierFactory;

  const ExploreScreen({
    super.key,
    required this.authNotifier,
    this.exploreNotifier,
    this.itineraryDetailNotifierFactory,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final ExploreNotifier _exploreNotifier;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _categoryThemes = [
    'Tất cả',
    'Nghỉ dưỡng',
    'Phượt',
    'Ẩm thực',
    'Khám phá',
    'Văn hóa',
    'Gia đình',
  ];

  @override
  void initState() {
    super.initState();
    _exploreNotifier = widget.exploreNotifier ?? ExploreNotifier();

    _scrollController.addListener(_onScroll);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exploreNotifier.loadInitialItineraries(token: widget.authNotifier.token);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    if (widget.exploreNotifier == null) {
      _exploreNotifier.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 250) {
      _exploreNotifier.loadMore(token: widget.authNotifier.token);
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(authNotifier: widget.authNotifier),
      ),
    );
  }

  void _handleFavoriteTap() {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng lưu yêu thích sẽ sớm được hỗ trợ.'),
          duration: Duration(seconds: 2),
        ),
      );
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
        final user = widget.authNotifier.currentUser;
        final displayName =
            user?['fullName'] ?? user?['username'] ?? 'Người dùng';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                SizedBox(width: 8),
                Text(
                  'Travel Planner',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              if (isAuthenticated)
                PopupMenuButton<String>(
                  tooltip: 'Tài khoản',
                  onSelected: (value) {
                    if (value == 'my_itineraries') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MyItinerariesScreen(
                            authNotifier: widget.authNotifier,
                          ),
                        ),
                      );
                    } else if (value == 'profile') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ProfileScreen(authNotifier: widget.authNotifier),
                        ),
                      );
                    } else if (value == 'logout') {
                      widget.authNotifier.logout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'my_itineraries',
                      child: Row(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Lịch trình của tôi',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: AppColors.error),
                          SizedBox(width: 10),
                          Text(
                            'Đăng xuất',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                )
              else
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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

                  // Horizontal Quick Theme Category Strip
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categoryThemes.length,
                      itemBuilder: (context, index) {
                        final theme = _categoryThemes[index];
                        final isAll = theme == 'Tất cả';
                        final isSelected = isAll
                            ? _exploreNotifier.filter.theme == null
                            : _exploreNotifier.filter.theme == theme;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(theme),
                            selected: isSelected,
                            onSelected: (_) {
                              _exploreNotifier.setQuickTheme(
                                isAll ? null : theme,
                                token: widget.authNotifier.token,
                              );
                            },
                            selectedColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.hairline,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      },
                    ),
                  ),

                  // Active Filter Summary (if active)
                  if (!_exploreNotifier.filter.isEmpty ||
                      _exploreNotifier.searchKeyword.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                              minimumSize: const Size(50, 30),
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

                  const SizedBox(height: 8),

                  // Results List / States
                  Expanded(child: _buildBody(context)),
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
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    Widget content;
    if (_exploreNotifier.isLoading) {
      content = const Center(
        key: ValueKey('explore_loading'),
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_exploreNotifier.isError) {
      content = AppErrorState(
        key: const ValueKey('explore_error'),
        message: _exploreNotifier.errorMessage ?? 'Đã có lỗi xảy ra',
        onRetry: () => _exploreNotifier.retry(token: widget.authNotifier.token),
      );
    } else if (_exploreNotifier.isEmptyResults) {
      content = AppEmptyState(
        key: const ValueKey('explore_empty'),
        title: 'Không tìm thấy lịch trình',
        message: 'Thử thay đổi từ khóa hoặc đặt lại bộ lọc để khám phá các chuyến đi khác.',
        actionText: 'Đặt lại bộ lọc',
        onActionPressed: () {
          _searchController.clear();
          _exploreNotifier.resetAllFilters(token: widget.authNotifier.token);
        },
      );
    } else {
      final itineraries = _exploreNotifier.itineraries;
      content = RefreshIndicator(
        key: const ValueKey('explore_list'),
        color: AppColors.primary,
        onRefresh: () => _exploreNotifier.fetchItineraries(
          resetPage: true,
          token: widget.authNotifier.token,
        ),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount:
              itineraries.length + (_exploreNotifier.isLoadingMore ? 1 : 0),
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
              onFavoriteTap: _handleFavoriteTap,
              onTap: () async {
                final result = await Navigator.of(context).push<dynamic>(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => ItineraryDetailScreen(
                      itineraryId: itinerary.itineraryId,
                      token: widget.authNotifier.token,
                      authNotifier: widget.authNotifier,
                      notifier: widget.itineraryDetailNotifierFactory?.call(
                        itinerary.itineraryId,
                        widget.authNotifier.token,
                      ),
                    ),
                  ),
                );
                if (result == true && mounted) {
                  _exploreNotifier.fetchItineraries(
                    resetPage: true,
                    token: widget.authNotifier.token,
                  );
                }
              },
            );
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      child: content,
    );
  }
}
