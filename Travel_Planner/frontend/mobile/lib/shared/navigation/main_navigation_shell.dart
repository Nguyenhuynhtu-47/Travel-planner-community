import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/explore/presentation/explore_notifier.dart';
import '../../features/explore/presentation/screens/explore_screen.dart';
import '../../features/itinerary/data/itinerary_crud_repository.dart';
import '../../features/itinerary/presentation/screens/create_itinerary_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/saved_itineraries/presentation/screens/saved_itineraries_screen.dart';
import '../../features/social/presentation/screens/community_screen.dart';

/// Main navigation shell containing the 5 bottom navigation destinations:
/// 1. Khám phá (Explore / Home) - Default
/// 2. Cộng đồng (Community)
/// 3. Tạo lịch trình (Create itinerary) - Center
/// 4. Đã lưu (Saved itineraries)
/// 5. Hồ sơ cá nhân (Personal profile)
class MainNavigationShell extends StatefulWidget {
  final AuthNotifier authNotifier;
  final int initialIndex;
  final ExploreNotifier? exploreNotifier;
  final ItineraryCrudRepository? itineraryRepository;
  final ProfileRepository? profileRepository;

  const MainNavigationShell({
    super.key,
    required this.authNotifier,
    this.initialIndex = 0,
    this.exploreNotifier,
    this.itineraryRepository,
    this.profileRepository,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onDestinationTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
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
          ),
          const CommunityScreen(),
          CreateItineraryScreen(
            authNotifier: widget.authNotifier,
            repository: widget.itineraryRepository,
            onCreated: (_) {
              setState(() {
                _currentIndex = 0;
              });
            },
          ),
          const SavedItinerariesScreen(),
          ProfileScreen(
            authNotifier: widget.authNotifier,
            repository: widget.profileRepository,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.hairlineSoft,
              width: 0.5,
            ),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Khám phá',
              tooltip: 'Khám phá',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Cộng đồng',
              tooltip: 'Cộng đồng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline, size: 28),
              activeIcon: Icon(Icons.add_circle, size: 28),
              label: 'Tạo lịch trình',
              tooltip: 'Tạo lịch trình',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_outline),
              activeIcon: Icon(Icons.bookmark),
              label: 'Đã lưu',
              tooltip: 'Đã lưu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hồ sơ',
              tooltip: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }
}
