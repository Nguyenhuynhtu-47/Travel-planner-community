import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/user_search_result.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MessagingRepository? repository;

  const UserSearchScreen({
    super.key,
    required this.authNotifier,
    this.repository,
  });

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  late final MessagingRepository _repository =
      widget.repository ?? MessagingRepository();
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<UserSearchResult> _results = [];
  int _page = 0;
  int _generation = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _searched = false;
  String? _error;

  String? get _token => widget.authNotifier.token;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _query.text.trim();
    if (query.length < 2) {
      _generation++;
      setState(() {
        _results = [];
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    final generation = ++_generation;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(query, generation: generation, reset: true);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    if (_scroll.position.extentAfter < 280) {
      _load(_query.text.trim(), generation: _generation, reset: false);
    }
  }

  Future<void> _load(
    String query, {
    required int generation,
    required bool reset,
  }) async {
    final token = _token;
    if (token == null || query.length < 2) return;
    setState(() {
      if (reset) {
        _loading = true;
        _page = 0;
        _results = [];
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final response = await _repository.searchUsers(
        query,
        token,
        page: reset ? 0 : _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final existing = _results.map((item) => item.userId).toSet();
      setState(() {
        _results = reset
            ? response.content
            : [
                ..._results,
                ...response.content.where((item) => existing.add(item.userId)),
              ];
        _page = response.pageNumber;
        _hasMore = !response.isLast;
        _searched = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = 'Không tìm kiếm được người dùng. Hãy thử lại.');
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final query = _query.text.trim();
    if (query.length >= 2) {
      final generation = ++_generation;
      await _load(query, generation: generation, reset: true);
    }
  }

  Future<void> _openProfile(UserSearchResult user) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          userId: user.userId,
          authNotifier: widget.authNotifier,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _act(UserSearchResult user, String action) async {
    final token = _token;
    final friendshipId = user.friendshipId;
    if (token == null) return;
    try {
      switch (action) {
        case 'add':
          await _repository.sendFriendRequest(user.userId, token);
          break;
        case 'accept':
          if (friendshipId != null) {
            await _repository.acceptFriendRequest(friendshipId, token);
          }
          break;
        case 'decline':
          if (friendshipId != null) {
            await _repository.declineFriendRequest(friendshipId, token);
          }
          break;
        case 'cancel':
          if (friendshipId != null) {
            await _repository.cancelFriendRequest(friendshipId, token);
          }
          break;
        case 'unfriend':
          await _repository.unfriend(user.userId, token);
          break;
      }
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thao tác không thành công. Hãy thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _message(UserSearchResult user) async {
    final token = _token;
    if (token == null) return;
    try {
      final conversation = await _repository.openDirect(user.userId, token);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            authNotifier: widget.authNotifier,
            repository: _repository,
            realtime: MessagingRealtimeClient.shared,
            conversation: conversation,
          ),
        ),
      );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa thể bắt đầu cuộc trò chuyện.')),
        );
      }
    }
  }

  Widget _avatar(UserSearchResult user) {
    final url = user.avatar?.trim() ?? '';
    return CircleAvatar(
      backgroundColor: AppColors.surfaceStrong,
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      onBackgroundImageError: url.isEmpty ? null : (_, _) {},
      child: url.isEmpty
          ? const Icon(Icons.person_outline, color: AppColors.muted)
          : null,
    );
  }

  Widget? _action(UserSearchResult user) {
    if (user.isSelf) return const Chip(label: Text('Bạn'));
    if (user.friendRequestDirection == 'received' &&
        user.friendshipId != null) {
      return Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Chấp nhận lời mời',
            onPressed: () => _act(user, 'accept'),
            icon: const Icon(Icons.check_circle_outline),
          ),
          IconButton(
            tooltip: 'Từ chối lời mời',
            onPressed: () => _act(user, 'decline'),
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
      );
    }
    if (user.friendRequestDirection == 'sent' && user.friendshipId != null) {
      return TextButton(
        onPressed: () => _act(user, 'cancel'),
        child: const Text('Đã gửi · Hủy'),
      );
    }
    if (user.friendshipStatus == 'ACCEPTED') {
      return Wrap(
        spacing: 4,
        children: [
          if (user.canMessage || user.canContinueConversation)
            IconButton(
              tooltip: 'Nhắn tin',
              onPressed: () => _message(user),
              icon: const Icon(Icons.chat_outlined),
            ),
          IconButton(
            tooltip: 'Hủy kết bạn',
            onPressed: () => _act(user, 'unfriend'),
            icon: const Icon(Icons.person_remove_alt_1_outlined),
          ),
        ],
      );
    }
    if (user.canSendFriendRequest) {
      return FilledButton.tonalIcon(
        onPressed: () => _act(user, 'add'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Kết bạn'),
      );
    }
    return user.canMessage || user.canContinueConversation
        ? IconButton(
            tooltip: 'Nhắn tin',
            onPressed: () => _message(user),
            icon: const Icon(Icons.chat_outlined),
          )
        : const Chip(label: Text('Không thể thao tác'));
  }

  @override
  Widget build(BuildContext context) {
    final queryTooShort = _query.text.trim().length < 2;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tìm người dùng'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm theo tên hoặc @handle',
                suffixIcon: IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: _query.clear,
                  icon: const Icon(Icons.close),
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_loading && _results.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _results.isEmpty)
            Expanded(
              child: Center(
                child: TextButton(onPressed: _refresh, child: Text(_error!)),
              ),
            )
          else if (queryTooShort && !_searched)
            const Expanded(
              child: AppEmptyState(
                icon: Icons.person_search_outlined,
                title: 'Tìm bạn đồng hành',
                message: 'Nhập ít nhất 2 ký tự của tên hoặc @handle.',
              ),
            )
          else if (_searched && _results.isEmpty)
            const Expanded(
              child: AppEmptyState(
                icon: Icons.search_off,
                title: 'Không tìm thấy người dùng',
                message: 'Thử tìm bằng tên hoặc @handle khác.',
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: _results.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _results.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final user = _results[index];
                    return ListTile(
                      leading: _avatar(user),
                      title: Text(
                        user.fullName?.trim().isNotEmpty == true
                            ? user.fullName!
                            : '@${user.handle}',
                      ),
                      subtitle: Text('@${user.handle}'),
                      onTap: () => _openProfile(user),
                      trailing: _action(user),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
