import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/app_header_button.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/messaging_date_time.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/conversation_summary.dart';
import 'chat_screen.dart';
import 'stranger_inbox_screen.dart';
import 'friends_screen.dart';

class MessagingInboxScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MessagingRepository? repository;
  const MessagingInboxScreen({
    super.key,
    required this.authNotifier,
    this.repository,
  });

  @override
  State<MessagingInboxScreen> createState() => _MessagingInboxScreenState();
}

class _MessagingInboxScreenState extends State<MessagingInboxScreen> {
  late final MessagingRepository _repository =
      widget.repository ?? MessagingRepository();
  late final MessagingRealtimeClient _realtime = MessagingRealtimeClient.shared;
  StreamSubscription? _events;
  List<ConversationSummary> _items = [];
  int _unreadMessageRequestCount = 0;
  String _filter = '';
  bool _loading = false;
  String? _error;
  String? get _token => widget.authNotifier.token;

  @override
  void initState() {
    super.initState();
    _events = _realtime.events.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final page = await _repository.conversations(token);
      var unreadMessageRequestCount = _unreadMessageRequestCount;
      try {
        unreadMessageRequestCount = await _repository.unreadMessageRequestCount(
          token,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = page.content;
        _unreadMessageRequestCount = unreadMessageRequestCount;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được danh sách tin nhắn.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(ConversationSummary item) =>
      item.peer.fullName?.trim().isNotEmpty == true
      ? item.peer.fullName!
      : '@${item.peer.effectiveHandle}';

  Future<void> _open(ConversationSummary item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          authNotifier: widget.authNotifier,
          repository: _repository,
          realtime: _realtime,
          conversation: item,
        ),
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
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person_outline, color: AppColors.muted),
            ),
          )
        : const Icon(Icons.person_outline, color: AppColors.muted),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where(
          (item) =>
              '${_name(item)} ${item.peer.effectiveHandle} ${item.lastMessage?.displayContent ?? ''}'
                  .toLowerCase()
                  .contains(_filter.toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leadingWidth: 58,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: AppHeaderBackButton()),
        ),
        title: const Text('Tin nhắn'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          AppHeaderIconButton(
            tooltip: 'Tin nhắn người lạ',
            icon: Icons.markunread_mailbox_outlined,
            badge: Badge(
              isLabelVisible: _unreadMessageRequestCount > 0,
              label: _unreadMessageRequestCount > 0
                  ? Text(
                      _unreadMessageRequestCount > 99
                          ? '99+'
                          : '$_unreadMessageRequestCount',
                    )
                  : null,
              child: const Icon(
                Icons.markunread_mailbox_outlined,
                size: 20,
                color: Color(0xFF1E1E1E),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StrangerInboxScreen(
                  authNotifier: widget.authNotifier,
                  repository: _repository,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppHeaderIconButton(
            tooltip: 'Bạn bè',
            icon: Icons.people_outline,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FriendsScreen(
                  authNotifier: widget.authNotifier,
                  repository: _repository,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _filter = value.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm trong tin nhắn',
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
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                ? Center(
                    child: BounceTap(
                      child: TextButton(onPressed: _load, child: Text(_error!)),
                    ),
                  )
                : filtered.isEmpty
                ? const AppEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Chưa có tin nhắn',
                    message: 'Bắt đầu trò chuyện với bạn bè để thấy hội thoại ở đây.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          leading: _avatar(item.peer.avatar),
                          title: Text(_name(item)),
                          subtitle: Text(
                            (item.lastMessage?.displayContent.isNotEmpty == true)
                                ? item.lastMessage!.displayContent
                                : (item.lastMessage?.content ?? 'Bắt đầu trò chuyện'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item.lastMessage?.createdAt != null ||
                                      item.updatedAt != null)
                                    Text(
                                      MessagingDateTime.format(
                                        item.lastMessage?.createdAt ??
                                            item.updatedAt!,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  if (item.unreadCount > 0)
                                    Badge(label: Text('${item.unreadCount}')),
                                ],
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Tùy chọn hội thoại',
                                onSelected: (action) => _manage(item, action),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'profile',
                                    child: Text('Xem trang cá nhân'),
                                  ),
                                  PopupMenuItem(
                                    value: 'block',
                                    child: Text('Chặn người dùng'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _open(item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _manage(ConversationSummary item, String action) async {
    if (action == 'profile') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            userId: item.peer.userId,
            authNotifier: widget.authNotifier,
          ),
        ),
      );
      return;
    }
    final confirmed = await AppDialog.showConfirm(
      context,
      type: AppDialogType.danger,
      title: 'Chặn người dùng?',
      message:
          'Bạn và người này sẽ không thể xem nội dung hoặc nhắn tin cho nhau.',
      confirmText: 'Chặn',
      cancelText: 'Hủy',
    );
    if (confirmed != true || !mounted) return;
    final token = _token;
    if (token == null) return;
    try {
      await _repository.block(item.peer.userId, token);
      await _load();
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể chặn người dùng lúc này.');
      }
    }
  }
}
