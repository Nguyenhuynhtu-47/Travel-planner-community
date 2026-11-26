import 'package:flutter/material.dart';

import '../../core/sync/app_sync_bus.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/bounce_tap.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/explore/presentation/explore_notifier.dart';
import '../../features/explore/presentation/screens/explore_screen.dart';
import '../../features/itinerary/data/itinerary_crud_repository.dart';
import '../../features/itinerary/presentation/screens/create_itinerary_screen.dart';
import '../../features/itinerary/presentation/screens/my_itineraries_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/collection/presentation/screens/collection_screen.dart';
import '../../features/collection/presentation/collection_notifier.dart';
import '../../features/collection/data/collection_repository.dart';
import '../../features/social/presentation/screens/community_screen.dart';
import '../../features/social/presentation/community_feed_notifier.dart';
import '../../features/social/data/community_post_repository.dart';
import '../../features/messaging/data/messaging_realtime_client.dart';

/// Main navigation shell containing the 5 bottom navigation destinations:
/// 1. Khám phá (Explore / Home) - Default
/// 2. Cộng đồng (Community)
/// 3. Tạo lịch trình (Create itinerary) - Center
/// 4. Bộ sưu tập (Collections / Saved & Favorites)
/// 5. Lịch trình của tôi (My Itineraries)
class MainNavigationShell extends StatefulWidget {
  final AuthNotifier authNotifier;
  final int initialIndex;
  final ExploreNotifier? exploreNotifier;
  final ItineraryCrudRepository? itineraryRepository;
  final ProfileRepository? profileRepository;
  final CollectionNotifier? collectionNotifier;
  final CollectionRepository? collectionRepository;
  final CommunityFeedNotifier? communityNotifier;
  final CommunityPostRepository? communityPostRepository;

  const MainNavigationShell({
    super.key,
    required this.authNotifier,
    this.initialIndex = 0,
    this.exploreNotifier,
    this.itineraryRepository,
    this.profileRepository,
    this.collectionNotifier,
    this.collectionRepository,
    this.communityNotifier,
    this.communityPostRepository,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  late final CommunityFeedNotifier _communityNotifier;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _communityNotifier = widget.communityNotifier ?? CommunityFeedNotifier();
    widget.authNotifier.addListener(_syncMessagingSession);
    _syncMessagingSession();
  }

  void _syncMessagingSession() {
    final auth = widget.authNotifier;
    final userId = '${auth.currentUser?['userId'] ?? ''}';
    if (auth.isAuthenticated && auth.token != null && userId.isNotEmpty) {
      MessagingRealtimeClient.shared.connect(auth.token!, userId);
    } else {
      MessagingRealtimeClient.shared.disconnect();
    }
  }

  @override
  void dispose() {
    widget.authNotifier.removeListener(_syncMessagingSession);
    MessagingRealtimeClient.shared.disconnect();
    if (widget.communityNotifier == null) {
      _communityNotifier.dispose();
    }
    super.dispose();
  }

  void _onDestinationTapped(int index) {
    if (index == _currentIndex) {
      if (index == 0) {
        AppSyncBus.requestRefresh(SyncDomain.notifications);
      }
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0:
        AppSyncBus.requestRefresh(SyncDomain.explore);
        AppSyncBus.requestRefresh(SyncDomain.notifications);
        break;
      case 1:
        AppSyncBus.requestRefresh(SyncDomain.posts);
        break;
      case 3:
        AppSyncBus.requestRefresh(SyncDomain.collections);
        break;
      case 4:
        AppSyncBus.requestRefresh(SyncDomain.itineraries);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _AnimatedTabStack(
        index: _currentIndex,
        children: [
          ExploreScreen(
            authNotifier: widget.authNotifier,
            exploreNotifier: widget.exploreNotifier,
            onProfileTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(
                  authNotifier: widget.authNotifier,
                  repository: widget.profileRepository,
                ),
              ),
            ),
          ),
          CommunityScreen(
            authNotifier: widget.authNotifier,
            notifier: _communityNotifier,
            repository: widget.communityPostRepository,
          ),
          CreateItineraryScreen(
            authNotifier: widget.authNotifier,
            repository: widget.itineraryRepository,
            onCreated: (_) {
              setState(() {
                _currentIndex = 4; // Switch to My Itineraries after creation
              });
              AppSyncBus.requestRefresh(SyncDomain.itineraries);
            },
          ),
          CollectionScreen(
            authNotifier: widget.authNotifier,
            notifier: widget.collectionNotifier,
            repository: widget.collectionRepository,
          ),
          MyItinerariesScreen(
            authNotifier: widget.authNotifier,
            repository: widget.itineraryRepository,
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _communityNotifier,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            border: const Border(
              top: BorderSide(color: Color(0xFFF0F0F5), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: _onDestinationTapped,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              selectedItemColor: const Color(0xFFFA3E62),
              unselectedItemColor: const Color(0xFF6E6E73),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconSize: 24,
              items: [
                BottomNavigationBarItem(
                  icon: const BounceTap.icon(
                    useSelectionHaptic: true,
                    child: Icon(Icons.explore_outlined),
                  ),
                  activeIcon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: _ActiveNavPill(
                      child: const Icon(
                        Icons.explore,
                        color: Color(0xFFFA3E62),
                      ),
                    ),
                  ),
                  label: 'Khám phá',
                  tooltip: 'Khám phá',
                ),
                BottomNavigationBarItem(
                  icon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: Badge(
                      isLabelVisible: _communityNotifier.hasCommunityActivity,
                      smallSize: _communityNotifier.unreadMessagesTotal == 0
                          ? 8
                          : null,
                      label: _communityNotifier.unreadMessagesTotal > 0
                          ? Text(
                              _communityNotifier.unreadMessagesTotal > 99
                                  ? '99+'
                                  : '${_communityNotifier.unreadMessagesTotal}',
                            )
                          : null,
                      child: const Icon(Icons.dynamic_feed_outlined),
                    ),
                  ),
                  activeIcon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: _ActiveNavPill(
                      child: Badge(
                        isLabelVisible: _communityNotifier.hasCommunityActivity,
                        smallSize: _communityNotifier.unreadMessagesTotal == 0
                            ? 8
                            : null,
                        label: _communityNotifier.unreadMessagesTotal > 0
                            ? Text(
                                _communityNotifier.unreadMessagesTotal > 99
                                    ? '99+'
                                    : '${_communityNotifier.unreadMessagesTotal}',
                              )
                            : null,
                        child: const Icon(
                          Icons.dynamic_feed_outlined,
                          color: Color(0xFFFA3E62),
                        ),
                      ),
                    ),
                  ),
                  label: 'Cộng đồng',
                  tooltip: 'Cộng đồng',
                ),
                const BottomNavigationBarItem(
                  icon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: _CenterCreateNavButton(isActive: false),
                  ),
                  activeIcon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: _CenterCreateNavButton(isActive: true),
                  ),
                  label: 'Tạo lịch trình',
                  tooltip: 'Tạo lịch trình',
                ),
                BottomNavigationBarItem(
                  icon: const BounceTap.icon(
                    useSelectionHaptic: true,
                    child: Icon(Icons.collections_bookmark_outlined),
                  ),
                  activeIcon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: _ActiveNavPill(
                      child: const Icon(
                        Icons.collections_bookmark,
                        color: Color(0xFFFA3E62),
                      ),
                    ),
                  ),
                  label: 'Bộ sưu tập',
                  tooltip: 'Bộ sưu tập',
                ),
                BottomNavigationBarItem(
                  icon: const BounceTap.icon(
                    useSelectionHaptic: true,
                    child: Icon(Icons.luggage_outlined),
                  ),
                  activeIcon: BounceTap.icon(
                    useSelectionHaptic: true,
                    child: _ActiveNavPill(
                      child: const Icon(
                        Icons.luggage,
                        color: Color(0xFFFA3E62),
                      ),
                    ),
                  ),
                  label: 'Lịch trình của tôi',
                  tooltip: 'Lịch trình của tôi',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preserves state of all tab children (like [IndexedStack]) while applying a
/// directional horizontal slide + subtle fade transition between tab switches.
class _AnimatedTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedTabStack({required this.index, required this.children});

  @override
  State<_AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<_AnimatedTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late int _currentIndex;
  int? _previousIndex;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _previousIndex = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      final disableMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      _isForward = widget.index > _currentIndex;
      _previousIndex = _currentIndex;
      _currentIndex = widget.index;

      if (disableMotion) {
        _previousIndex = null;
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAnimating =
        _previousIndex != null &&
        _controller.status != AnimationStatus.completed;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _buildChild(i, isAnimating),
      ],
    );
  }

  Widget _buildChild(int i, bool isAnimating) {
    final isCurrent = i == _currentIndex;
    final isPrevious = isAnimating && i == _previousIndex;
    final isVisible = isCurrent || isPrevious;

    final dir = _isForward ? 1.0 : -1.0;
    final Animation<Offset> slideAnim;
    final Animation<double> fadeAnim;

    if (isAnimating && isCurrent) {
      slideAnim = Tween<Offset>(
        begin: Offset(0.18 * dir, 0.0),
        end: Offset.zero,
      ).animate(_animation);
      fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_animation);
    } else if (isAnimating && isPrevious) {
      slideAnim = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-0.12 * dir, 0.0),
      ).animate(_animation);
      fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(_animation);
    } else {
      slideAnim = const AlwaysStoppedAnimation<Offset>(Offset.zero);
      fadeAnim = const AlwaysStoppedAnimation<double>(1.0);
    }

    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(
        opacity: fadeAnim,
        child: TickerMode(
          enabled: isVisible,
          child: Offstage(
            offstage: !isVisible,
            child: IgnorePointer(
              ignoring: !isCurrent,
              child: widget.children[i],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveNavPill extends StatelessWidget {
  final Widget child;

  const _ActiveNavPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _CenterCreateNavButton extends StatelessWidget {
  final bool isActive;

  const _CenterCreateNavButton({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 46,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFA3E62), Color(0xFFFF7A8F)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFA3E62)
                .withValues(alpha: isActive ? 0.36 : 0.24),
            blurRadius: isActive ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        isActive ? Icons.add_circle : Icons.add_circle_outline,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}
