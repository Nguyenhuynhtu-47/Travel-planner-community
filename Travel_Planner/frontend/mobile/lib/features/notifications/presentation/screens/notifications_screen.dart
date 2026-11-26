import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/sync/app_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../../social/presentation/screens/post_detail_screen.dart';
import '../../data/models/notification_item.dart';
import '../../data/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final NotificationRepository? repository;

  const NotificationsScreen({super.key, this.authNotifier, this.repository});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  late final NotificationRepository _repository;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<SyncEvent>? _syncSubscription;
  List<NotificationItem> _items = [];
  String? _nextCursor;
  String? _error;
  String? _accountKey;
  int _unreadCount = 0;
  int _personalUnreadCount = 0;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _readAllBusy = false;
  final Set<String> _readingIds = {};

  String? get _token => widget.authNotifier?.token;
  String? get _currentAccount =>
      widget.authNotifier?.currentUser?['userId']?.toString();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? NotificationRepository();
    _accountKey = _currentAccount;
    widget.authNotifier?.addListener(_onAuthChanged);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _syncSubscription = AppSyncBus.instance
        .on(SyncDomain.notifications)
        .listen((_) => _refreshInBackground());
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authNotifier != widget.authNotifier) {
      oldWidget.authNotifier?.removeListener(_onAuthChanged);
      widget.authNotifier?.addListener(_onAuthChanged);
      _resetForAccountChange();
    }
  }

  void _onAuthChanged() {
    if (_accountKey == _currentAccount) return;
    _resetForAccountChange();
  }

  void _resetForAccountChange() {
    _accountKey = _currentAccount;
    setState(() {
      _items = [];
      _nextCursor = null;
      _hasMore = false;
      _error = null;
      _unreadCount = 0;
      _personalUnreadCount = 0;
      _initialLoading = true;
      _loadingMore = false;
      _readAllBusy = false;
      _readingIds.clear();
    });
    _loadFirstPage();
  }

  Future<void> _loadFirstPage({bool showLoading = true}) async {
    final token = _token;
    final account = _currentAccount;
    if (token == null || account == null) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _unreadCount = 0;
        _personalUnreadCount = 0;
        _initialLoading = false;
        _error = null;
      });
      return;
    }
    if (showLoading && mounted) {
      setState(() {
        _initialLoading = true;
        _error = null;
      });
    }
    try {
      final result = await Future.wait([
        _repository.getPage(token),
        _repository.getUnreadSummary(token),
      ]);
      if (!mounted || token != _token || account != _currentAccount) return;
      final page = result[0] as NotificationPage;
      setState(() {
        _items = _deduplicate(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor != null;
        final unread = result[1] as NotificationUnreadSummary;
        _unreadCount = unread.count;
        _personalUnreadCount = unread.personalCount;
        _initialLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || token != _token || account != _currentAccount) return;
      setState(() {
        _initialLoading = false;
        _error = 'Không thể tải thông báo. Vui lòng thử lại.';
      });
    }
  }

  List<NotificationItem> _deduplicate(List<NotificationItem> items) {
    final seen = <String>{};
    return items.where((item) => seen.add(item.stableKey)).toList();
  }

  Future<void> _loadMore() async {
    final token = _token;
    final account = _currentAccount;
    final cursor = _nextCursor;
    if (token == null || cursor == null || !_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.getPage(token, cursor: cursor);
      if (!mounted || token != _token || account != _currentAccount) return;
      final existingIds = _items.map((item) => item.stableKey).toSet();
      setState(() {
        _items = [
          ..._items,
          ...page.items.where((item) => existingIds.add(item.stableKey)),
        ];
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore && page.nextCursor != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && token == _token && account == _currentAccount) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải thêm thông báo.')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) _loadMore();
  }

  Future<void> _refreshInBackground() async {
    if (!mounted || _initialLoading) return;
    await _loadFirstPage(showLoading: false);
  }

  Future<void> _refresh() async => _loadFirstPage(showLoading: false);

  Future<void> _markAllRead() async {
    final token = _token;
    if (token == null || _readAllBusy || _unreadCount == 0) return;
    setState(() => _readAllBusy = true);
    try {
      // Bulk-read is reserved for personal events. Announcement receipts are
      // intentionally created only when that announcement itself is opened.
      await _repository.markAllRead(token);
      if (!mounted || token != _token) return;
      setState(() => _readAllBusy = false);
      await _loadFirstPage(showLoading: false);
      AppSyncBus.requestRefresh(SyncDomain.notifications);
    } catch (_) {
      if (mounted) {
        setState(() => _readAllBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đánh dấu đã đọc. Hãy thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _openNotification(NotificationItem item) async {
    final token = _token;
    if (token == null || _readingIds.contains(item.stableKey)) return;
    if (!item.isRead) {
      setState(() => _readingIds.add(item.stableKey));
      try {
        if (item.isAnnouncement) {
          await _repository.markAnnouncementRead(item.id, token);
        } else {
          await _repository.markRead(item.id, token);
        }
        if (!mounted || token != _token) return;
        setState(() {
          _readingIds.remove(item.stableKey);
          _items = _items
              .map(
                (entry) => entry.stableKey == item.stableKey
                    ? NotificationItem(
                        id: entry.id,
                        type: entry.type,
                        title: entry.title,
                        body: entry.body,
                        targetType: entry.targetType,
                        targetId: entry.targetId,
                        actor: entry.actor,
                        createdAt: entry.createdAt,
                        readAt: DateTime.now(),
                        isAnnouncement: entry.isAnnouncement,
                      )
                    : entry,
              )
              .toList();
          _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
          if (!item.isAnnouncement) {
            _personalUnreadCount = (_personalUnreadCount - 1).clamp(0, 1 << 31);
          }
        });
        AppSyncBus.requestRefresh(SyncDomain.notifications);
      } catch (_) {
        if (mounted) {
          setState(() => _readingIds.remove(item.stableKey));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể cập nhật trạng thái thông báo.'),
            ),
          );
        }
        return;
      }
    }
    await _navigateToTarget(item);
  }

  Future<void> _navigateToTarget(NotificationItem item) async {
    final id = int.tryParse(item.targetId ?? '');
    Widget? destination;
    if (id != null) {
      switch (item.targetType) {
        case 'USER':
          destination = PublicProfileScreen(
            userId: id,
            authNotifier: widget.authNotifier,
          );
        case 'POST':
          destination = PostDetailScreen(
            postId: id,
            authNotifier: widget.authNotifier,
          );
        case 'ITINERARY':
          destination = ItineraryDetailScreen(
            itineraryId: id,
            authNotifier: widget.authNotifier,
          );
        case 'ANNOUNCEMENT':
          destination = _AnnouncementDetailScreen(item: item);
      }
    }
    if (!mounted) return;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.targetType == 'REPORT'
                ? 'Chưa thể mở chi tiết báo cáo này một cách an toàn.'
                : 'Nội dung này chưa có liên kết mở trực tiếp.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => destination!));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshInBackground();
  }

  @override
  void dispose() {
    widget.authNotifier?.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Thông báo', fontSize: 18),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_personalUnreadCount > 0)
            TextButton(
              onPressed: _readAllBusy ? null : _markAllRead,
              child: _readAllBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Đọc tất cả'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.hairlineSoft),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.authNotifier?.isAuthenticated != true || _token == null) {
      return const AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Đăng nhập để xem thông báo',
        message: 'Thông báo cá nhân chỉ hiển thị với tài khoản đã đăng nhập.',
      );
    }
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return AppErrorState(message: _error!, onRetry: _loadFirstPage);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            AppEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Chưa có thông báo',
              message: 'Khi có hoạt động hoặc cập nhật mới liên quan đến bạn, thông báo sẽ xuất hiện tại đây.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 76, color: AppColors.hairlineSoft),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return _NotificationTile(
            item: item,
            busy: _readingIds.contains(item.stableKey),
            onTap: () => _openNotification(item),
          );
        },
      ),
    );
  }
}

class _AnnouncementDetailScreen extends StatelessWidget {
  final NotificationItem item;
  const _AnnouncementDetailScreen({required this.item});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông báo hệ thống')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(item.body),
      ],
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final bool busy;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.busy,
    required this.onTap,
  });

  IconData get _icon => switch (item.type) {
    'FRIEND_REQUEST' || 'FRIEND_REQUEST_ACCEPTED' => Icons.person_add_alt_1,
    'NEW_FOLLOWER' => Icons.person_add_alt,
    'POST_LIKE' => Icons.favorite_border,
    'POST_COMMENT' || 'POST_COMMENT_REPLY' => Icons.chat_bubble_outline,
    'ITINERARY_COMMENT' ||
    'ACTIVITY_COMMENT' ||
    'COMMENT_REPLY' => Icons.travel_explore,
    'SYSTEM' => Icons.info_outline,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final actorName = item.actor.displayName?.trim();
    final imageUrl = item.actor.avatar;
    return Material(
      color: item.isRead ? AppColors.background : AppColors.primaryLight,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceStrong,
                child: imageUrl == null || imageUrl.isEmpty
                    ? const Icon(Icons.person_outline, color: AppColors.muted)
                    : ClipOval(
                        child: Image.network(
                          imageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_outline,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isNotEmpty
                                ? item.title
                                : actorName ?? 'Thông báo',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(_icon, size: 18, color: AppColors.primary),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
              if (busy) ...[
                const SizedBox(width: 8),
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
