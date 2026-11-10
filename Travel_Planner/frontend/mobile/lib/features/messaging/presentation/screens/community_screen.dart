import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/conversation_summary.dart';
import '../../data/models/friend_request.dart';
import 'chat_screen.dart';
import 'messaging_settings_screen.dart';

class CommunityScreen extends StatefulWidget {
  final AuthNotifier? authNotifier;
  final MessagingRealtimeClient? realtime;
  final MessagingRepository? repository;
  const CommunityScreen({
    super.key,
    this.authNotifier,
    this.realtime,
    this.repository,
  });
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late final MessagingRepository _repo =
      widget.repository ?? MessagingRepository();
  late final MessagingRealtimeClient _realtime =
      widget.realtime ?? MessagingRealtimeClient.shared;
  StreamSubscription? _events;
  List<ConversationSummary> _conversations = [];
  List<dynamic> _friends = [];
  List<FriendRequest> _incoming = [], _outgoing = [];
  bool _loading = false;
  String? _activeAccountKey;
  String? _error;
  String? get _token => widget.authNotifier?.token;
  @override
  void initState() {
    super.initState();
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
        });
      }
      _activeAccountKey = id;
      _realtime.connect(auth.token!, id);
      _load();
    } else {
      _activeAccountKey = null;
      _realtime.disconnect();
      if (mounted)
        setState(() {
          _conversations = [];
          _friends = [];
          _incoming = [];
          _outgoing = [];
        });
    }
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _repo.conversations(token),
        _repo.friends(token),
        _repo.requests(token, 'received'),
        _repo.requests(token, 'sent'),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = values[0].content as List<ConversationSummary>;
        _friends = values[1].content;
        _incoming = values[2].content as List<FriendRequest>;
        _outgoing = values[3].content as List<FriendRequest>;
        _error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Không tải được tin nhắn và bạn bè.');
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

  Widget _avatar(String? url) => CircleAvatar(
    backgroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
    child: url?.isNotEmpty == true ? null : const Icon(Icons.person_outline),
  );
  Widget _inbox() {
    if (_loading && _conversations.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (_error != null && _conversations.isEmpty)
      return Center(
        child: TextButton(onPressed: _load, child: Text(_error!)),
      );
    if (_conversations.isEmpty)
      return const AppEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Chưa có tin nhắn',
        message: 'Mở hồ sơ một người bạn để bắt đầu trò chuyện.',
      );
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
                    c.updatedAt!.toLocal().toString(),
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
    if (_loading && _friends.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (_friends.isEmpty)
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'Chưa có bạn bè',
        message: 'Kết nối với người dùng qua hồ sơ công khai.',
      );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: _friends
            .map(
              (u) => ListTile(
                leading: _avatar(u.avatar),
                title: Text(_name(u)),
                trailing: IconButton(
                  tooltip: 'Nhắn tin',
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: () async {
                    try {
                      final c = await _repo.openDirect(u.userId, _token!);
                      if (mounted) _open(c);
                    } catch (_) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Không thể mở cuộc trò chuyện.'),
                          ),
                        );
                    }
                  },
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
              leading: _avatar(r.otherUser.avatar),
              title: Text(_name(r.otherUser)),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Chấp nhận',
                    onPressed: () async {
                      await _repo.acceptFriendRequest(r.friendshipId, _token!);
                      _load();
                    },
                    icon: const Icon(Icons.check, color: AppColors.primary),
                  ),
                  IconButton(
                    tooltip: 'Từ chối',
                    onPressed: () async {
                      await _repo.declineFriendRequest(r.friendshipId, _token!);
                      _load();
                    },
                    icon: const Icon(Icons.close),
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
              leading: _avatar(r.otherUser.avatar),
              title: Text(_name(r.otherUser)),
              subtitle: const Text('Đang chờ phản hồi'),
              trailing: TextButton(
                onPressed: () async {
                  await _repo.cancelFriendRequest(r.friendshipId, _token!);
                  _load();
                },
                child: const Text('Hủy'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authNotifier;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Cộng đồng du lịch',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (auth?.isAuthenticated == true)
            IconButton(
              tooltip: 'Quyền riêng tư tin nhắn',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MessagingSettingsScreen(
                    token: auth!.token!,
                    repository: _repo,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Thông báo',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
          ),
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
                  tabs: [
                    Tab(
                      text:
                          'Tin nhắn${_conversations.isNotEmpty ? ' (${_conversations.length})' : ''}',
                    ),
                    const Tab(text: 'Bạn bè'),
                    const Tab(text: 'Lời mời'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [_inbox(), _friendsTab(), _requests()],
                  ),
                ),
              ],
            ),
    );
  }
}
