import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_header_button.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/messaging_repository.dart';
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
  static const List<Color> _pastelBgColors = [
    Color(0xFFFFF0F3),
    Color(0xFFEFF6FF),
    Color(0xFFECFDF5),
    Color(0xFFFFFBEB),
    Color(0xFFF5F3FF),
  ];

  static const List<Color> _pastelTextColors = [
    Color(0xFFFA3E62),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
  ];

  late final MessagingRepository _repository =
      widget.repository ?? MessagingRepository();
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<UserSearchResult> _suggestions = [];
  List<UserSearchResult> _results = [];
  int _page = 0;
  int _generation = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingSuggestions = false;
  bool _loadingMore = false;
  bool _searched = false;
  String? _error;
  String? _suggestionsError;

  String? get _token => widget.authNotifier.token;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
    _scroll.addListener(_onScroll);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loadingSuggestions = true;
      _suggestionsError = null;
    });
    try {
      final response = await _repository.suggestedUsers(token, size: 10);
      if (!mounted) return;
      setState(() {
        _suggestions = response.content.take(10).toList();
        _suggestionsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = 'Không thể tải danh sách gợi ý. Hãy thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSuggestions = false);
      }
    }
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
    setState(() {});
    final generation = ++_generation;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(query, generation: generation, reset: true);
    });
  }

  void _onScroll() {
    if (_query.text.trim().length < 2) return;
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
    } else {
      await _loadSuggestions();
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
        AppToast.showError(context, 'Thao tác không thành công. Hãy thử lại.');
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
        AppToast.showError(context, 'Chưa thể bắt đầu cuộc trò chuyện.');
      }
    }
  }

  Widget _buildAvatar(UserSearchResult user) {
    final url = user.avatar?.trim() ?? '';
    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : user.handle.trim();
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';
    final colorIndex = user.userId.abs() % _pastelBgColors.length;

    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _pastelBgColors[colorIndex],
        border: Border.all(color: const Color(0xFFEFEFF4), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _pastelTextColors[colorIndex],
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _pastelTextColors[colorIndex],
                ),
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color textColor,
    IconData? icon,
  }) {
    return Expanded(
      child: BounceTap(
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: textColor),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonsRow(UserSearchResult user) {
    if (user.isSelf) {
      return Row(
        children: [
          _buildActionButton(
            label: 'Xem trang',
            onTap: () => _openProfile(user),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF1E1E1E),
          ),
        ],
      );
    }

    if (user.friendRequestDirection == 'received' &&
        user.friendshipId != null) {
      return Row(
        children: [
          _buildActionButton(
            label: 'Chấp nhận',
            icon: Icons.check_rounded,
            onTap: () => _act(user, 'accept'),
            backgroundColor: const Color(0xFFFA3E62),
            textColor: Colors.white,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Từ chối',
            onTap: () => _act(user, 'decline'),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF1E1E1E),
          ),
        ],
      );
    }

    if (user.friendRequestDirection == 'sent' && user.friendshipId != null) {
      return Row(
        children: [
          _buildActionButton(
            label: 'Đã gửi lời mời',
            onTap: () => _act(user, 'cancel'),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF4B5563),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Xem trang',
            onTap: () => _openProfile(user),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF1E1E1E),
          ),
        ],
      );
    }

    if (user.friendshipStatus == 'ACCEPTED') {
      return Row(
        children: [
          if (user.canMessage || user.canContinueConversation)
            _buildActionButton(
              label: 'Nhắn tin',
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => _message(user),
              backgroundColor: const Color(0xFFFFF0F3),
              textColor: const Color(0xFFFA3E62),
            )
          else
            _buildActionButton(
              label: 'Bạn bè',
              icon: Icons.check_rounded,
              onTap: () => _openProfile(user),
              backgroundColor: const Color(0xFFF3F4F6),
              textColor: const Color(0xFF4B5563),
            ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Xem trang',
            onTap: () => _openProfile(user),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF1E1E1E),
          ),
        ],
      );
    }

    if (user.canSendFriendRequest) {
      return Row(
        children: [
          _buildActionButton(
            label: 'Thêm bạn',
            icon: Icons.person_add_alt_1_rounded,
            onTap: () => _act(user, 'add'),
            backgroundColor: const Color(0xFFFA3E62),
            textColor: Colors.white,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Xem trang',
            onTap: () => _openProfile(user),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF1E1E1E),
          ),
        ],
      );
    }

    if (user.canMessage || user.canContinueConversation) {
      return Row(
        children: [
          _buildActionButton(
            label: 'Nhắn tin',
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => _message(user),
            backgroundColor: const Color(0xFFFFF0F3),
            textColor: const Color(0xFFFA3E62),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Xem trang',
            onTap: () => _openProfile(user),
            backgroundColor: const Color(0xFFF3F4F6),
            textColor: const Color(0xFF1E1E1E),
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildActionButton(
          label: 'Xem trang',
          onTap: () => _openProfile(user),
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF1E1E1E),
        ),
      ],
    );
  }

  Widget _buildUserItem(UserSearchResult user) {
    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : '@${user.handle}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BounceTap(
            child: GestureDetector(
              onTap: () => _openProfile(user),
              child: _buildAvatar(user),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BounceTap(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openProfile(user),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.handle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildButtonsRow(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody({
    required String headerTitle,
    required List<UserSearchResult> items,
    required bool showLoadingMore,
  }) {
    return RefreshIndicator(
      color: const Color(0xFFFA3E62),
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: 1 + items.length + (showLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                headerTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            );
          }
          final itemIndex = index - 1;
          if (itemIndex == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFA3E62)),
              ),
            );
          }
          return _buildUserItem(items[itemIndex]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearchMode = _query.text.trim().length >= 2;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leadingWidth: 58,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Center(child: AppHeaderBackButton()),
          ),
          title: const Text(
            'Tìm người dùng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF6E6E73),
                    size: 21,
                  ),
                  hintText: 'Tìm theo tên hoặc @handle',
                  hintStyle: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF6E6E73),
                  ),
                  suffixIcon: _query.text.isNotEmpty
                      ? BounceTap.icon(
                          child: IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: _query.clear,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF6E6E73),
                              size: 20,
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: isSearchMode
                  ? _buildSearchContent()
                  : _buildSuggestionsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFA3E62)),
      );
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        child: BounceTap(
          child: TextButton(onPressed: _refresh, child: Text(_error!)),
        ),
      );
    }
    if (_searched && _results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Không tìm thấy người dùng phù hợp',
        message: 'Thử tìm bằng tên hoặc @handle khác.',
      );
    }
    return _buildListBody(
      headerTitle: 'Kết quả tìm kiếm',
      items: _results,
      showLoadingMore: _loadingMore,
    );
  }

  Widget _buildSuggestionsContent() {
    if (_loadingSuggestions && _suggestions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFA3E62)),
      );
    }
    if (_suggestionsError != null && _suggestions.isEmpty) {
      return Center(
        child: BounceTap(
          child: TextButton(
            onPressed: _loadSuggestions,
            child: Text(_suggestionsError!),
          ),
        ),
      );
    }
    if (_suggestions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Tìm bạn đồng hành',
        message: 'Nhập ít nhất 2 ký tự của tên hoặc @handle.',
      );
    }
    return _buildListBody(
      headerTitle: 'Gợi ý bạn đồng hành',
      items: _suggestions,
      showLoadingMore: false,
    );
  }
}
