import 'package:flutter/material.dart';
import 'package:travel_planner_web/core/constants/api_constants.dart';
import 'package:travel_planner_web/core/network/api_client.dart';
import 'package:travel_planner_web/core/theme/app_colors.dart';
import 'package:travel_planner_web/features/auth/presentation/auth_notifier.dart';
import 'package:travel_planner_web/features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:travel_planner_web/features/locations/presentation/screens/admin_places_screen.dart';
import 'package:travel_planner_web/features/moderation/presentation/screens/admin_moderation_screen.dart';
import 'package:travel_planner_web/features/profile/presentation/screens/profile_screen.dart';
import 'package:travel_planner_web/features/layout/domain/admin_tab.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/admin_header.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/admin_sidebar.dart';
import 'package:travel_planner_web/features/layout/presentation/widgets/placeholder_feature_view.dart';

class AdminShell extends StatefulWidget {
  final AuthNotifier authNotifier;
  final AdminTab initialTab;
  final ApiClient? apiClient;

  const AdminShell({
    super.key,
    required this.authNotifier,
    this.initialTab = AdminTab.dashboard,
    this.apiClient,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late AdminTab _currentTab;
  bool _isSidebarCollapsed = false;
  String? _healthStatus;
  int _pendingReportsCount = 0;
  late final ApiClient _apiClient;

  bool get isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _apiClient = widget.apiClient ?? ApiClient();
    _fetchSystemStatus();
  }

  Future<void> _fetchSystemStatus() async {
    // 1. Health check
    try {
      final res = await _apiClient.get(ApiConstants.healthEndpoint);
      if (mounted && res is Map<String, dynamic>) {
        setState(() {
          _healthStatus = res['status']?.toString() ?? 'UP';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _healthStatus = 'UNAVAILABLE';
        });
      }
    }

    // 2. Pending reports badge
    final token = widget.authNotifier.token;
    if (token != null && token.isNotEmpty) {
      try {
        final res = await _apiClient.get(
          '${ApiConstants.adminCommunityReportsEndpoint}?status=PENDING&page=0&size=1',
          token: token,
        );
        if (mounted && res is Map<String, dynamic>) {
          final total = res['totalElements'];
          if (total is num) {
            setState(() {
              _pendingReportsCount = total.toInt();
            });
          }
        }
      } catch (_) {
        // Ignore badge fetch error
      }
    }
  }

  void _onSelectTab(AdminTab tab) {
    if (_currentTab != tab) {
      setState(() {
        _currentTab = tab;
      });
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _logout() {
    widget.authNotifier.logout();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_outlined, size: 56, color: AppColors.error),
                    const SizedBox(height: 18),
                    const Text(
                      'Truy cập bị từ chối',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Bạn cần tài khoản có vai trò Quản trị viên (ADMIN) để truy cập hệ thống quản trị này.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Đăng xuất'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 42),
                      ),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoCollapse = constraints.maxWidth < 960;
        final effectiveCollapsed = _isSidebarCollapsed || autoCollapse;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              // Sidebar
              AdminSidebar(
                currentTab: _currentTab,
                onSelectTab: _onSelectTab,
                isCollapsed: effectiveCollapsed,
                onToggleCollapse: _toggleSidebar,
                currentUser: widget.authNotifier.currentUser,
                onLogout: _logout,
                pendingReportsCount: _pendingReportsCount,
              ),

              // Main area
              Expanded(
                child: Column(
                  children: [
                    // Header
                    AdminHeader(
                      currentTab: _currentTab,
                      currentUser: widget.authNotifier.currentUser,
                      onToggleSidebar: _toggleSidebar,
                      onGoToProfile: () => _onSelectTab(AdminTab.profile),
                      onLogout: _logout,
                      healthStatus: _healthStatus,
                    ),

                    // Main Content
                    Expanded(
                      child: _buildCurrentContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentContent() {
    switch (_currentTab) {
      case AdminTab.dashboard:
        return AdminDashboardScreen(
          authNotifier: widget.authNotifier,
          onNavigateTab: _onSelectTab,
        );
      case AdminTab.posts:
        return AdminModerationScreen(
          authNotifier: widget.authNotifier,
          initialTabIndex: 0,
          embedded: true,
        );
      case AdminTab.reports:
        return AdminModerationScreen(
          authNotifier: widget.authNotifier,
          initialTabIndex: 1,
          embedded: true,
        );
      case AdminTab.media:
        return AdminModerationScreen(
          authNotifier: widget.authNotifier,
          initialTabIndex: 2,
          embedded: true,
        );
      case AdminTab.places:
        return AdminPlacesScreen(
          authNotifier: widget.authNotifier,
          embedded: true,
        );
      case AdminTab.profile:
        return ProfileScreen(
          authNotifier: widget.authNotifier,
          embedded: true,
        );
      case AdminTab.users:
      case AdminTab.itineraries:
      case AdminTab.administrativeAreas:
      case AdminTab.auditLogs:
      case AdminTab.settings:
        return PlaceholderFeatureView(
          tab: _currentTab,
          onGoToDashboard: () => _onSelectTab(AdminTab.dashboard),
        );
    }
  }
}
