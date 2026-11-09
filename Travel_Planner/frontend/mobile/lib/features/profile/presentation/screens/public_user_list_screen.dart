import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
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
  final List<PublicUserSummary> _users = [];
  int _nextPage = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(reset: true);
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final title = widget.followers ? 'Người theo dõi' : 'Đang theo dõi';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
          : ListView.separated(
              controller: _scrollController,
              itemCount:
                  _users.length +
                  (_loadingMore || _hasMore || _error != null ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  if (_error != null) {
                    return Center(
                      child: TextButton(
                        onPressed: _loadPage,
                        child: const Text('Tải lại'),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.base),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final user = _users[index];
                final displayName = user.fullName?.trim().isNotEmpty == true
                    ? user.fullName!.trim()
                    : user.username;
                return ListTile(
                  minLeadingWidth: AppSpacing.xl,
                  leading: CircleAvatar(
                    backgroundImage: user.avatar?.isNotEmpty == true
                        ? NetworkImage(user.avatar!)
                        : null,
                    child: user.avatar?.isNotEmpty == true
                        ? null
                        : const Icon(Icons.person_outline),
                  ),
                  title: Text(displayName),
                  subtitle: Text('@${user.username}'),
                  onTap: () => widget.onUserSelected(user),
                );
              },
            ),
    );
  }
}
