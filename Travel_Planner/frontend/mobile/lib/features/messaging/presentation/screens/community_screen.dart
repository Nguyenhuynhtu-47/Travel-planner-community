import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/messaging_date_time.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_title.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/app_header_button.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../../shared/widgets/current_user_avatar_button.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/conversation_summary.dart';
import '../../data/models/friend_request.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import 'chat_screen.dart';
import 'messaging_settings_screen.dart';
import 'user_search_screen.dart';

class CommunityScreen extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final MessagingRealtimeClient? realtime;
  final MessagingRepository? repository;
  final int initialTab;
  const CommunityScreen({
    super.key,
    this.authNotifier,
    this.realtime,
    this.repository,
    this.initialTab = 0,
  });
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final MessagingRepository _repo =
      widget.repository ?? MessagingRepository();
  late final MessagingRealtimeClient _realtime =
      widget.realtime ?? MessagingRealtimeClient.shared;
  StreamSubscription? _events;
  List<ConversationSummary> _conversations = [];
  List<ConversationSummary> _messageRequests = [];
  List<dynamic> _friends = [];
  List<FriendRequest> _incoming = [], _outgoing = [];
  int _incomingTotal = 0, _messageRequestTotal = 0;
  bool _loading = false;
  String? _activeAccountKey;
  String? _error;
  String? get _token => widget.authNotifier?.token;
  @override
  void initState() {
    super.initState();
    final initialTab = widget.initialTab < 0
        ? 0
        : widget.initialTab > 3
        ? 3
        : widget.initialTab;
    _tabs = TabController(length: 4, initialIndex: initialTab, vsync: this);
    widget.authNotifier?.addListener(_authChanged);
    _events = _realtime.events.listen((event) {
      if (mounted) _load();
    });
    _authChanged();
  }

  @override
  void dispose() {
    widget.authNotifier?.removeListener(_authChanged);
    _events?.cancel();
    _tabs.dispose();

    super.dispose();
  }

  void _authChanged() {
    final auth = widget.authNotifier;
    if (auth?.isAuthenticated == true && auth?.token != null) {
      final id = '${auth!.currentUser?['userId'] ?? ''}';
      if (_activeAccountKey != null && _activeAccountKey != id && mounted) {
        setState(() {
          _conversations = [];
          _friends = [];
          _incoming = [];
          _outgoing = [];
          _messageRequests = [];
          _incomingTotal = 0;
          _messageRequestTotal = 0;
        });
      }
      _activeAccountKey = id;
      _realtime.connect(auth.token!, id);
      _load();
    } else {
      _activeAccountKey = null;
      _realtime.disconnect();
      if (mounted) {
        setState(() {
          _conversations = [];
          _friends = [];
          _incoming = [];
          _outgoing = [];
          _messageRequests = [];
          _incomingTotal = 0;
          _messageRequestTotal = 0;
        });
      }
    }
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        _repo.conversations(token),
        _repo.friends(token),
        _repo.requests(token, 'received'),
        _repo.requests(token, 'sent'),
        _repo.messageRequests(token),
        _repo.pendingMessageRequestCount(token),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = values[0].content as List<ConversationSummary>;
        _friends = values[1].content;
        _incoming = values[2].content as List<FriendRequest>;
        _outgoing = values[3].content as List<FriendRequest>;
        _messageRequests = values[4].content as List<ConversationSummary>;
        _incomingTotal = values[2].totalElements;
        _messageRequestTotal = values[5] as int;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được tin nhắn và bạn bè.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _name(dynamic u) => u.fullName?.trim().isNotEmpty == true
      ? u.fullName
      : '@${u.effectiveHandle}';
  Future<void> _open(ConversationSummary c) async {
    final auth = widget.authNotifier;
    if (auth == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          authNotifier: auth,
          repository: _repo,
          realtime: _realtime,
          conversation: c,
        ),
      ),
    );
    _load();
  }

  Future<void> _openProfile(int userId) async {
    final auth = widget.authNotifier;
    if (auth == null || userId <= 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(userId: userId, authNotifier: auth),
      ),
    );
    if (mounted) _load();
  }

  Widget _avatar(String? url) => CircleAvatar(
    backgroundColor: AppColors.surfaceStrong,
    child: url?.trim().isNotEmpty == true
        ? ClipOval(
            child: Image.network(
              url!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.person_outline, color: AppColors.muted),
            ),
          )
        : const Icon(Icons.person_outline, color: AppColors.muted),
  );
  Widget _inbox() {
    if (_loading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _conversations.isEmpty) {
      return Center(
        child: BounceTap(
          child: TextButton(onPressed: _load, child: Text(_error!)),
        ),
      );
    }
    if (_conversations.isEmpty) {
      return const AppEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Chưa có tin nhắn',
        message: 'Mở hồ sơ một người bạn để bắt đầu trò chuyện.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, i) {
          final c = _conversations[i];
          return ListTile(
            leading: _avatar(c.peer.avatar),
            title: Text(_name(c.peer)),
            subtitle: Text(
              c.lastMessage?.content ?? 'Bắt đầu trò chuyện',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (c.updatedAt != null)
                  Text(
                    MessagingDateTime.format(
                      c.lastMessage?.createdAt ?? c.updatedAt!,
                    ),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                if (c.unreadCount > 0) Badge(label: Text('${c.unreadCount}')),
              ],
            ),
            onTap: () => _open(c),
          );
        },
      ),
    );
  }

  Widget _friendsTab() {
    if (_loading && _friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'Chưa có bạn bè',
        message: 'Kết nối với người dùng qua hồ sơ công khai.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: _friends
            .map(
              (u) => ListTile(
                leading: _avatar(u.avatar),
                title: Text(_name(u)),
                onTap: () => _openProfile(u.userId),
                trailing: BounceTap.icon(
                  child: IconButton(
                    tooltip: 'Nhắn tin',
                    icon: const Icon(Icons.chat_outlined),
                    onPressed: () async {
                      try {
                        final c = await _repo.openDirect(u.userId, _token!);
                        if (mounted) _open(c);
                      } catch (_) {
                        if (mounted) {
                          AppToast.showError(
                            context,
                            'Không thể mở cuộc trò chuyện.',
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _requests() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_incoming.isEmpty && _outgoing.isEmpty)
            const AppEmptyState(
              icon: Icons.person_add_alt,
              title: 'Chưa có lời mời',
              message: 'Lời mời kết bạn sẽ xuất hiện ở đây.',
            ),
          if (_incoming.isNotEmpty)
            const ListTile(
              title: Text(
                'Lời mời đến',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ..._incoming.map(
            (r) => ListTile(
              leading: BounceTap(
                child: GestureDetector(
                  onTap: () => _openProfile(r.otherUser.userId),
                  child: _avatar(r.otherUser.avatar),
                ),
              ),
              title: Text(_name(r.otherUser)),
              onTap: () => _openProfile(r.otherUser.userId),
              trailing: Wrap(
                children: [
                  BounceTap.icon(
                    child: IconButton(
                      tooltip: 'Chấp nhận',
                      onPressed: () async {
                        await _repo.acceptFriendRequest(r.friendshipId, _token!);
                        _load();
                      },
                      icon: const Icon(Icons.check, color: AppColors.primary),
                    ),
                  ),
                  BounceTap.icon(
                    child: IconButton(
                      tooltip: 'Từ chối',
                      onPressed: () async {
                        await _repo.declineFriendRequest(r.friendshipId, _token!);
                        _load();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_outgoing.isNotEmpty)
            const ListTile(
              title: Text(
                'Đã gửi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ..._outgoing.map(
            (r) => ListTile(
              leading: BounceTap(
                child: GestureDetector(
                  onTap: () => _openProfile(r.otherUser.userId),
                  child: _avatar(r.otherUser.avatar),
                ),
              ),
              title: Text(_name(r.otherUser)),
              onTap: () => _openProfile(r.otherUser.userId),
              subtitle: const Text('Đang chờ phản hồi'),
              trailing: BounceTap(
                child: TextButton(
                  onPressed: () async {
                    await _repo.cancelFriendRequest(r.friendshipId, _token!);
                    _load();
                  },
                  child: const Text('Hủy'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strangerRequests() {
    if (_loading && _messageRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messageRequests.isEmpty) {
      return const AppEmptyState(
        icon: Icons.markunread_mailbox_outlined,
        title: 'Chưa có yêu cầu tin nhắn',
        message: 'Tin nhắn từ người chưa kết bạn sẽ xuất hiện ở đây.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: _messageRequests.map((request) {
          final peer = request.peer;
          return ListTile(
            leading: BounceTap(
              child: GestureDetector(
                onTap: () => _openProfile(peer.userId),
                child: _avatar(peer.avatar),
              ),
            ),
            title: Text(_name(peer)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  request.lastMessage?.content ?? 'Yêu cầu tin nhắn mới',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (request.lastMessage?.createdAt != null ||
                    request.updatedAt != null)
                  Text(
                    MessagingDateTime.format(
                      request.lastMessage?.createdAt ?? request.updatedAt!,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
            onTap: () => _open(request),
            trailing: BounceTap.icon(
              child: IconButton(
                tooltip: 'Xem yêu cầu',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _open(request),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authNotifier;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppPageTitle(title: 'Cộng đồng du lịch', fontSize: 18),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (auth?.isAuthenticated == true) ...[
            AppHeaderIconButton(
              tooltip: 'Tìm người dùng',
              icon: Icons.person_search_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      UserSearchScreen(authNotifier: auth!, repository: _repo),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppHeaderIconButton(
              tooltip: 'Quyền riêng tư tin nhắn',
              icon: Icons.settings_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MessagingSettingsScreen(
                    token: auth!.token!,
                    repository: _repo,
                  ),
                ),
              ),
            ),
          if (auth?.isAuthenticated == true)
            CurrentUserAvatarButton(
              avatarUrl: auth?.currentUser?['avatar']?.toString(),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(authNotifier: auth!),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: auth?.isAuthenticated != true
          ? const AppEmptyState(
              icon: Icons.people_outline,
              title: 'Cộng đồng du lịch',
              message: 'Đăng nhập để sử dụng tin nhắn và kết bạn.',
            )
          : Column(
              children: [
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.primary,
                  isScrollable: true,
                  tabs: [
                    BounceTap(
                      useSelectionHaptic: true,
                      child: Tab(
                        text:
                            'Tin nhắn${_conversations.isNotEmpty ? ' (${_conversations.length})' : ''}',
                      ),
                    ),
                    const BounceTap(
                      useSelectionHaptic: true,
                      child: Tab(text: 'Bạn bè'),
                    ),
                    BounceTap(
                      useSelectionHaptic: true,
                      child: Tab(
                        text: _incomingTotal > 0
                            ? 'Lời mời ($_incomingTotal)'
                            : 'Lời mời',
                      ),
                    ),
                    BounceTap(
                      useSelectionHaptic: true,
                      child: Tab(
                        text: _messageRequestTotal > 0
                            ? 'Người lạ ($_messageRequestTotal)'
                            : 'Người lạ',
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _inbox(),
                      _friendsTab(),
                      _requests(),
                      _strangerRequests(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
