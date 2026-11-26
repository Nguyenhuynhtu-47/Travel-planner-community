import 'package:flutter/material.dart';
import 'package:mobile/shared/widgets/app_header_button.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/models/public_user_summary.dart';
import '../../data/public_profile_repository.dart';

class PublicUserListScreen extends StatefulWidget {
  final int userId;
  final bool followers;
  final PublicProfileRepository repository;
  final AuthNotifier? authNotifier;
  final ValueChanged<PublicUserSummary> onUserSelected;

  const PublicUserListScreen({
    super.key,
    required this.userId,
    required this.followers,
    required this.repository,
    required this.onUserSelected,
    this.authNotifier,
  });

  @override
  State<PublicUserListScreen> createState() => _PublicUserListScreenState();
}

class _PublicUserListScreenState extends State<PublicUserListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<PublicUserSummary> _users = [];
  final Map<int, bool> _followingOverrides = {};
  final Set<int> _togglingUserIds = {};
  int _nextPage = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  int? get _currentUserId =>
      int.tryParse('${widget.authNotifier?.currentUser?['userId'] ?? ''}');

  bool get _isViewingOwnFollowing =>
      !widget.followers &&
      _currentUserId != null &&
      _currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240) _loadPage();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loadingMore || (!_hasMore && !reset)) return;
    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _hasMore = true;
        _nextPage = 0;
        _users.clear();
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await widget.repository.users(
        widget.userId,
        followers: widget.followers,
        page: _nextPage,
        token: widget.authNotifier?.token,
      );
      if (!mounted) return;
      setState(() {
        _users.addAll(
          page.content.where(
            (user) => !_users.any((existing) => existing.userId == user.userId),
          ),
        );
        _nextPage = page.pageNumber + 1;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải danh sách.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  bool _isFollowingUser(PublicUserSummary user) {
    return _followingOverrides[user.userId] ?? _isViewingOwnFollowing;
  }

  Future<void> _toggleFollow(PublicUserSummary user) async {
    final token = widget.authNotifier?.token;
    if (token == null || token.isEmpty) {
      AppToast.showInfo(context, 'Vui lòng đăng nhập để theo dõi người dùng.');
      return;
    }
    if (_togglingUserIds.contains(user.userId)) return;

    final currentlyFollowing = _isFollowingUser(user);
    setState(() {
      _togglingUserIds.add(user.userId);
      _followingOverrides[user.userId] = !currentlyFollowing;
    });

    try {
      if (currentlyFollowing) {
        await widget.repository.unfollow(user.userId, token);
      } else {
        await widget.repository.follow(user.userId, token);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followingOverrides[user.userId] = currentlyFollowing;
      });
      AppToast.showError(context, 'Thao tác không thành công. Hãy thử lại.');
    } finally {
      if (mounted) {
        setState(() => _togglingUserIds.remove(user.userId));
      }
    }
  }

  List<PublicUserSummary> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      final name = (user.fullName ?? '').toLowerCase();
      final handle = user.effectiveHandle.toLowerCase();
      return name.contains(query) || handle.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.followers ? 'Người theo dõi' : 'Đang theo dõi';
    final displayedUsers = _filteredUsers;

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
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFEBEBEF)),
          ),
        ),
        body: Column(
          children: [
            if (_users.isNotEmpty || _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E1E1E),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm trong danh sách...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF6E6E73),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? BounceTap.icon(
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF6E6E73),
                                ),
                                onPressed: _searchController.clear,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF4F5F7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading && _users.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFA3E62),
                      ),
                    )
                  : _error != null && _users.isEmpty
                  ? AppErrorState(
                      message: _error!,
                      onRetry: () => _loadPage(reset: true),
                    )
                  : _users.isEmpty
                  ? AppEmptyState(
                      title: 'Danh sách đang trống',
                      message: widget.followers
                          ? 'Chưa có ai theo dõi người dùng này.'
                          : 'Người dùng này chưa theo dõi ai.',
                      icon: Icons.people_outline,
                    )
                  : displayedUsers.isEmpty
                  ? const AppEmptyState(
                      title: 'Không tìm thấy kết quả',
                      message: 'Thử nhập tên hoặc @handle khác.',
                      icon: Icons.search_off_rounded,
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount:
                          displayedUsers.length +
                          (_searchController.text.isEmpty &&
                                  (_loadingMore || _hasMore || _error != null)
                              ? 1
                              : 0),
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 76,
                        color: Color(0xFFF3F4F6),
                      ),
                      itemBuilder: (context, index) {
                        if (index == displayedUsers.length) {
                          if (_error != null) {
                            return Center(
                              child: BounceTap(
                                child: TextButton(
                                  onPressed: _loadPage,
                                  child: const Text('Tải lại'),
                                ),
                              ),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.base),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFA3E62),
                              ),
                            ),
                          );
                        }
                        final user = displayedUsers[index];
                        final handleDisplay = user.effectiveHandle.isNotEmpty
                            ? user.effectiveHandle
                            : 'user';
                        final displayName =
                            user.fullName?.trim().isNotEmpty == true
                            ? user.fullName!.trim()
                            : '@$handleDisplay';
                        final isSelf = _currentUserId == user.userId;
                        final isFollowing = _isFollowingUser(user);
                        final isBusy = _togglingUserIds.contains(user.userId);

                        return BounceTap(
                          child: InkWell(
                            onTap: () => widget.onUserSelected(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFF4F5F7),
                                      border: Border.all(
                                        color: const Color(0xFFEFEFF4),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: user.avatar?.isNotEmpty == true
                                        ? Image.network(
                                            user.avatar!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.person_outline,
                                                  color: Color(0xFF8E8E93),
                                                ),
                                          )
                                        : const Icon(
                                            Icons.person_outline,
                                            color: Color(0xFF8E8E93),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@$handleDisplay',
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
                                  if (!isSelf &&
                                      widget.authNotifier?.token != null) ...[
                                    const SizedBox(width: 10),
                                    BounceTap(
                                      enabled: !isBusy,
                                      child: Material(
                                        color: isFollowing
                                            ? const Color(0xFFF3F4F6)
                                            : const Color(0xFFFFF0F3),
                                        borderRadius: BorderRadius.circular(16),
                                        child: InkWell(
                                          onTap: isBusy
                                              ? null
                                              : () => _toggleFollow(user),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              isFollowing
                                                  ? 'Đang theo dõi'
                                                  : 'Theo dõi lại',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: isFollowing
                                                    ? const Color(0xFF1E1E1E)
                                                    : const Color(0xFFFA3E62),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
