import 'package:flutter/material.dart';
import '../../../../shared/widgets/admin_tab_bar.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../layout/domain/admin_tab.dart';
import '../../data/moderation_repository.dart';
import 'admin_media_screen.dart';
import 'admin_posts_screen.dart';
import 'admin_reports_screen.dart';

export 'admin_media_screen.dart';
export 'admin_posts_screen.dart';
export 'admin_reports_screen.dart';

/// Legacy compatibility wrapper for moderation screens.
/// In the unified navigation architecture, prefer using [AdminPostsScreen],
/// [AdminReportsScreen], or [AdminMediaScreen] directly via [AdminSidebar].
class AdminModerationScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final ModerationRepository? repository;
  final int initialTabIndex;
  final bool embedded;
  final ValueChanged<AdminTab>? onNavigateTab;

  const AdminModerationScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.initialTabIndex = 0,
    this.embedded = false,
    this.onNavigateTab,
  });

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get isAdmin {
    final role =
        widget.authNotifier.currentUser?['role']?.toString().toUpperCase();
    return role == 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(AdminModerationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex >= 0 &&
        widget.initialTabIndex < 3 &&
        _tabController.index != widget.initialTabIndex) {
      _tabController.index = widget.initialTabIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kiểm duyệt cộng đồng')),
        body: const Center(
          child: Text(
            'Quyền truy cập bị từ chối: Chỉ tài khoản Quản trị viên (ADMIN) mới có quyền truy cập.',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Quản trị & Kiểm duyệt Cộng đồng'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flat SaaS Nested Tab Bar (retained for backward compatibility / multi-tab view)
          AdminTabBar(
            controller: _tabController,
            tabs: const [
              'Bài viết',
              'Báo cáo vi phạm',
              'Tài nguyên Media',
            ],
            onTap: (index) {
              final tab = switch (index) {
                0 => AdminTab.posts,
                1 => AdminTab.reports,
                _ => AdminTab.media,
              };
              widget.onNavigateTab?.call(tab);
            },
          ),

          // Standalone Screen Delegations
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AdminPostsScreen(
                  key: const ValueKey('standalone_posts_screen'),
                  authNotifier: widget.authNotifier,
                  repository: widget.repository,
                  embedded: true,
                ),
                AdminReportsScreen(
                  key: const ValueKey('standalone_reports_screen'),
                  authNotifier: widget.authNotifier,
                  repository: widget.repository,
                  embedded: true,
                ),
                AdminMediaScreen(
                  key: const ValueKey('standalone_media_screen'),
                  authNotifier: widget.authNotifier,
                  repository: widget.repository,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
