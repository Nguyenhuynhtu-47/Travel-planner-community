import 'package:flutter/material.dart';

import '../../core/sync/app_sync_bus.dart';
import '../../core/theme/app_colors.dart';
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
      body: IndexedStack(
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
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.hairlineSoft, width: 0.5),
            ),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onDestinationTapped,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.muted,
            backgroundColor: AppColors.surface,
            elevation: 0,
            iconSize: 24,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Khám phá',
                tooltip: 'Khám phá',
              ),
              BottomNavigationBarItem(
                icon: Badge(
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
                  child: Icon(Icons.group_outlined),
                ),
                activeIcon: Badge(
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
                  child: Icon(Icons.group),
                ),
                label: 'Cộng đồng',
                tooltip: 'Cộng đồng',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline, size: 28),
                activeIcon: Icon(Icons.add_circle, size: 28),
                label: 'Tạo lịch trình',
                tooltip: 'Tạo lịch trình',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.collections_bookmark_outlined),
                activeIcon: Icon(Icons.collections_bookmark),
                label: 'Bộ sưu tập',
                tooltip: 'Bộ sưu tập',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.luggage_outlined),
                activeIcon: Icon(Icons.luggage),
                label: 'Lịch trình của tôi',
                tooltip: 'Lịch trình của tôi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
