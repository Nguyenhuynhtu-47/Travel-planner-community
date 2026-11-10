import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../explore/data/models/itinerary_summary.dart';
import '../../../explore/presentation/widgets/itinerary_card.dart';
import '../../../itinerary/presentation/screens/itinerary_detail_screen.dart';
import '../../data/models/public_profile.dart';
import '../../data/models/public_user_summary.dart';
import '../../data/public_profile_repository.dart';
import '../../../messaging/data/messaging_repository.dart';
import '../../../messaging/data/messaging_realtime_client.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import 'profile_screen.dart';
import 'public_user_list_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final int userId;
  final AuthNotifier? authNotifier;
  final PublicProfileRepository? repository;
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.authNotifier,
    this.repository,
  });
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final PublicProfileRepository _repo =
      widget.repository ?? PublicProfileRepository();
  final ScrollController _scroll = ScrollController();
  PublicProfile? _profile;
  List<ItinerarySummary> _itineraries = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _followBusy = false;
  bool _relationshipBusy = false;
  final MessagingRepository _messaging = MessagingRepository();
  String? _error, _moreError;
  String? get _token => widget.authNotifier?.token;

  bool get _following => _profile?.isFollowing ?? false;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _page = 0;
      _hasMore = true;
      _itineraries.clear();
    });
    try {
      final profile = await _repo.getProfile(widget.userId, token: _token);
      final page = await _repo.itineraries(widget.userId, token: _token);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _itineraries = page.content;
        _page = page.pageNumber;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể tải hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.itineraries(
        widget.userId,
        page: _page + 1,
        token: _token,
      );
      if (mounted) {
        setState(() {
          _itineraries.addAll(page.content);
          _page = page.pageNumber;
          _hasMore = page.hasMore;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _moreError = 'Không thể tải thêm lịch trình.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để theo dõi người dùng.')),
      );
      return;
    }
    if (_followBusy) return;
    final old = _following;
    setState(() => _followBusy = true);
    try {
      if (old) {
        await _repo.unfollow(widget.userId, token);
      } else {
        await _repo.follow(widget.userId, token);
      }
      if (mounted) {
        final profile = _profile;
        if (profile != null) {
          setState(() {
            _profile = profile.copyWith(
              isFollowing: !old,
              followerCount: (profile.followerCount + (old ? -1 : 1))
                  .clamp(0, 1 << 31)
                  .toInt(),
            );
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật theo dõi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _relationshipAction(String action) async {
    final token = _token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để kết nối với người dùng.')),
      );
      return;
    }
    if (_relationshipBusy) return;
    setState(() => _relationshipBusy = true);
    try {
      final status = _profile?.friendshipStatus;
      final direction = _profile?.friendRequestDirection;
      if (action == 'send')
        await _messaging.sendFriendRequest(widget.userId, token);
      if (action == 'accept') {
        final requests = await _messaging.requests(token, 'received');
        final match = requests.content
            .where((item) => item.otherUser.userId == widget.userId)
            .firstOrNull;
        if (match != null)
          await _messaging.acceptFriendRequest(match.friendshipId, token);
      }
      if (action == 'cancel' || action == 'decline') {
        final requests = await _messaging.requests(
          token,
          direction == 'received' ? 'received' : 'sent',
        );
        final match = requests.content
            .where((item) => item.otherUser.userId == widget.userId)
            .firstOrNull;
        if (match != null) {
          if (action == 'cancel')
            await _messaging.cancelFriendRequest(match.friendshipId, token);
          else
            await _messaging.declineFriendRequest(match.friendshipId, token);
        }
      }
      if (action == 'unfriend' && status == 'ACCEPTED')
        await _messaging.unfriend(widget.userId, token);
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật quan hệ bạn bè.')),
        );
    } finally {
      if (mounted) setState(() => _relationshipBusy = false);
    }
  }

  Future<void> _openConversation() async {
    final token = _token;
    if (token == null || widget.authNotifier == null) return;
    try {
      final conversation = await _messaging.openDirect(widget.userId, token);
      final realtime = MessagingRealtimeClient()
        ..connect(
          token,
          '${widget.authNotifier!.currentUser?['userId'] ?? ''}',
        );
      if (!mounted) {
        realtime.dispose();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            authNotifier: widget.authNotifier!,
            repository: _messaging,
            realtime: realtime,
            conversation: conversation,
          ),
        ),
      );

      _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chưa thể nhắn tin cho người dùng này.'),
          ),
        );
    }
  }

  Widget _relationshipActions(PublicProfile profile) {
    if (profile.isOwnProfile || widget.authNotifier == null)
      return const SizedBox.shrink();
    final direction = profile.friendRequestDirection;
    final pending = profile.friendshipStatus == 'PENDING';
    final accepted = profile.friendshipStatus == 'ACCEPTED';
    final actions = <Widget>[];
    if (profile.canMessage)
      actions.add(
        OutlinedButton.icon(
          onPressed: _relationshipBusy ? null : _openConversation,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Nhắn tin'),
        ),
      );
    if (accepted)
      actions.add(
        TextButton(
          onPressed: _relationshipBusy
              ? null
              : () => _relationshipAction('unfriend'),
          child: const Text('Bạn bè · Hủy kết bạn'),
        ),
      );
    else if (pending && direction == 'received') {
      actions.addAll([
        FilledButton(
          onPressed: _relationshipBusy
              ? null
              : () => _relationshipAction('accept'),
          child: const Text('Chấp nhận'),
        ),
        TextButton(
          onPressed: _relationshipBusy
              ? null
              : () => _relationshipAction('decline'),
          child: const Text('Từ chối'),
        ),
      ]);
    } else if (pending && direction == 'sent')
      actions.add(
        OutlinedButton(
          onPressed: _relationshipBusy
              ? null
              : () => _relationshipAction('cancel'),
          child: const Text('Hủy lời mời'),
        ),
      );
    else if (profile.canSendFriendRequest)
      actions.add(
        FilledButton(
          onPressed: _relationshipBusy
              ? null
              : () => _relationshipAction('send'),
          child: const Text('Thêm bạn bè'),
        ),
      );
    if (_relationshipBusy)
      actions.add(
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: actions,
    );
  }

  Future<void> _openUsers(bool followers) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserListScreen(
          userId: widget.userId,
          followers: followers,
          repository: _repo,
          authNotifier: widget.authNotifier,
          onUserSelected: _openSelectedProfile,
        ),
      ),
    );
    _load();
  }

  void _openSelectedProfile(PublicUserSummary user) {
    final currentUserId = int.tryParse(
      '${widget.authNotifier?.currentUser?['userId'] ?? ''}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            currentUserId == user.userId && widget.authNotifier != null
            ? ProfileScreen(authNotifier: widget.authNotifier!)
            : PublicProfileScreen(
                userId: user.userId,
                authNotifier: widget.authNotifier,
                repository: _repo,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (_error != null || profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message: _error ?? 'Không tìm thấy hồ sơ.',
          onRetry: _load,
        ),
      );
    }
    final handleDisplay = profile.effectiveHandle.isNotEmpty
        ? profile.effectiveHandle
        : 'user';
    final name = profile.fullName?.trim().isNotEmpty == true
        ? profile.fullName!.trim()
        : '@$handleDisplay';
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage: profile.avatar?.isNotEmpty == true
                    ? NetworkImage(profile.avatar!)
                    : null,
                child: profile.avatar?.isNotEmpty == true
                    ? null
                    : const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Text(
                name,
                style: AppTextStyles.displaySm.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Center(
              child: Text(
                '@$handleDisplay',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (profile.bio?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                profile.bio!.trim(),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.textBody),
              ),
            ],
            const SizedBox(height: AppSpacing.base),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _openUsers(true),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: _count('Người theo dõi', profile.followerCount),
                ),
                const SizedBox(width: AppSpacing.xl),
                InkWell(
                  onTap: () => _openUsers(false),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: _count('Đang theo dõi', profile.followingCount),
                ),
              ],
            ),
            if (!profile.isOwnProfile)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: FilledButton(
                  onPressed: _followBusy ? null : _toggleFollow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: _followBusy
                      ? const SizedBox.square(
                          dimension:
                              AppSpacing.md + AppSpacing.xs + AppSpacing.xxs,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Text(_following ? 'Đang theo dõi' : 'Theo dõi'),
                ),
              ),
            if (!profile.isOwnProfile)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _relationshipActions(profile),
              ),
            if (profile.isOwnProfile && widget.authNotifier != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ProfileScreen(authNotifier: widget.authNotifier!),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa hồ sơ'),
                ),
              ),
            const Divider(height: AppSpacing.xxl),
            Text(
              'Lịch trình công khai',
              style: AppTextStyles.titleMd.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (_itineraries.isEmpty)
              const AppEmptyState(
                title: 'Chưa có lịch trình công khai',
                message:
                    'Các lịch trình công khai của người dùng sẽ hiện ở đây.',
                icon: Icons.luggage_outlined,
              ),
            for (final item in _itineraries)
              ItineraryCard(
                itinerary: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ItineraryDetailScreen(
                      itineraryId: item.itineraryId,
                      initialSummary: item,
                      token: _token,
                      authNotifier: widget.authNotifier,
                    ),
                  ),
                ),
              ),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.base),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_moreError != null)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _moreError = null);
                    _loadMore();
                  },
                  child: const Text('Thử tải thêm'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _count(String label, int count) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Column(
      children: [
        Text(
          '$count',
          style: AppTextStyles.titleMd.copyWith(color: AppColors.textPrimary),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
