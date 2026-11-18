import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/data/models/public_user_summary.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/conversation_summary.dart';
import '../../data/models/friend_request.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';

class FriendsScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MessagingRepository? repository;
  final int initialTab;
  const FriendsScreen({
    super.key,
    required this.authNotifier,
    this.repository,
    this.initialTab = 0,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final MessagingRepository _repository =
      widget.repository ?? MessagingRepository();
  late final TabController _tabs = TabController(
    length: 2,
    initialIndex: widget.initialTab.clamp(0, 1),
    vsync: this,
  );
  StreamSubscription? _events;
  List<PublicUserSummary> _friends = [];
  List<FriendRequest> _incoming = [];
  List<FriendRequest> _outgoing = [];
  String _friendFilter = '';
  bool _loading = false;
  String? _error;
  String? get _token => widget.authNotifier.token;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_tabChanged);
    _events = MessagingRealtimeClient.shared.events.listen((_) => _load());
    _load();
  }

  void _tabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _events?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final result = await Future.wait<dynamic>([
        _repository.friends(token),
        _repository.requests(token, 'received'),
        _repository.requests(token, 'sent'),
      ]);
      if (mounted) {
        setState(() {
          _friends = result[0].content as List<PublicUserSummary>;
          _incoming = result[1].content as List<FriendRequest>;
          _outgoing = result[2].content as List<FriendRequest>;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được danh sách bạn bè.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(PublicUserSummary user) =>
      user.fullName?.trim().isNotEmpty == true
      ? user.fullName!
      : '@${user.effectiveHandle}';

  Widget _avatar(String? url) => CircleAvatar(
    backgroundColor: AppColors.surfaceStrong,
    child: url?.trim().isNotEmpty == true
        ? ClipOval(
            child: Image.network(
              url!,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person_outline, color: AppColors.muted),
            ),
          )
        : const Icon(Icons.person_outline, color: AppColors.muted),
  );

  Future<void> _openProfile(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PublicProfileScreen(userId: id, authNotifier: widget.authNotifier),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _message(int userId) async {
    final token = _token;
    if (token == null) return;
    try {
      final ConversationSummary conversation = await _repository.openDirect(
        userId,
        token,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            authNotifier: widget.authNotifier,
            repository: _repository,
            conversation: conversation,
          ),
        ),
      );
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở cuộc trò chuyện.')),
        );
      }
    }
  }

  Future<void> _requestAction(FriendRequest request, String action) async {
    final token = _token;
    if (token == null) return;
    try {
      switch (action) {
        case 'accept':
          await _repository.acceptFriendRequest(request.friendshipId, token);
          break;
        case 'decline':
          await _repository.declineFriendRequest(request.friendshipId, token);
          break;
        case 'cancel':
          await _repository.cancelFriendRequest(request.friendshipId, token);
          break;
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật lời mời.')),
        );
      }
    }
  }

  Widget _friendsList() {
    final filtered = _friends
        .where(
          (user) => '${_name(user)} ${user.effectiveHandle}'
              .toLowerCase()
              .contains(_friendFilter.toLowerCase()),
        )
        .toList();
    if (_loading && _friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _friends.isEmpty) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(_error!)),
      );
    }
    if (filtered.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'Chưa có bạn bè',
        message: 'Tìm người dùng để kết nối và lên kế hoạch cùng nhau.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final user = filtered[index];
          return ListTile(
            leading: _avatar(user.avatar),
            title: Text(_name(user)),
            subtitle: Text('@${user.effectiveHandle}'),
            onTap: () => _openProfile(user.userId),
            trailing: IconButton(
              tooltip: 'Nhắn tin',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => _message(user.userId),
            ),
          );
        },
      ),
    );
  }

  Widget _requestList() {
    if (_loading && _incoming.isEmpty && _outgoing.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (_incoming.isEmpty && _outgoing.isEmpty)
            const AppEmptyState(
              icon: Icons.person_add_alt_1,
              title: 'Chưa có lời mời',
              message: 'Lời mời kết bạn đến và đã gửi sẽ xuất hiện ở đây.',
            ),
          if (_incoming.isNotEmpty)
            const ListTile(
              title: Text(
                'Lời mời đến',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ..._incoming.map(
            (request) => ListTile(
              leading: GestureDetector(
                onTap: () => _openProfile(request.otherUser.userId),
                child: _avatar(request.otherUser.avatar),
              ),
              title: Text(_name(request.otherUser)),
              subtitle: Text('@${request.otherUser.effectiveHandle}'),
              onTap: () => _openProfile(request.otherUser.userId),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Chấp nhận',
                    onPressed: () => _requestAction(request, 'accept'),
                    icon: const Icon(Icons.check, color: AppColors.primary),
                  ),
                  IconButton(
                    tooltip: 'Từ chối',
                    onPressed: () => _requestAction(request, 'decline'),
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
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ..._outgoing.map(
            (request) => ListTile(
              leading: GestureDetector(
                onTap: () => _openProfile(request.otherUser.userId),
                child: _avatar(request.otherUser.avatar),
              ),
              title: Text(_name(request.otherUser)),
              subtitle: const Text('Đang chờ phản hồi'),
              onTap: () => _openProfile(request.otherUser.userId),
              trailing: TextButton(
                onPressed: () => _requestAction(request, 'cancel'),
                child: const Text('Hủy'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Bạn bè'),
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: 'Tìm người dùng',
          icon: const Icon(Icons.person_search_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => UserSearchScreen(
                authNotifier: widget.authNotifier,
                repository: _repository,
              ),
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          tabs: [
            Tab(
              text: 'Bạn bè${_friends.isEmpty ? '' : ' (${_friends.length})'}',
            ),
            Tab(
              text:
                  'Lời mời${_incoming.isEmpty ? '' : ' (${_incoming.length})'}',
            ),
          ],
        ),
        if (_tabs.index == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _friendFilter = value.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm trong danh sách bạn bè',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_friendsList(), _requestList()],
          ),
        ),
      ],
    ),
  );
}
