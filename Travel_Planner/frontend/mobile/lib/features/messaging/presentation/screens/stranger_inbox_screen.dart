import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_toast.dart';
import 'package:mobile/shared/widgets/bounce_tap.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/messaging_date_time.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/conversation_summary.dart';
import 'chat_screen.dart';

class StrangerInboxScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MessagingRepository? repository;
  const StrangerInboxScreen({
    super.key,
    required this.authNotifier,
    this.repository,
  });

  @override
  State<StrangerInboxScreen> createState() => _StrangerInboxScreenState();
}

class _StrangerInboxScreenState extends State<StrangerInboxScreen> {
  late final MessagingRepository _repository =
      widget.repository ?? MessagingRepository();
  final MessagingRealtimeClient _realtime = MessagingRealtimeClient.shared;
  StreamSubscription? _events;
  List<ConversationSummary> _items = [];
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
      final response = await _repository.messageRequests(token);
      if (mounted) {
        setState(() {
          _items = response.content;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được tin nhắn từ người lạ.');
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

  Future<void> _block(ConversationSummary item) async {
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
      await _block(item);
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể chặn người dùng lúc này.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Tin nhắn người lạ'),
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
        ? Center(
            child: BounceTap(
              child: TextButton(onPressed: _load, child: Text(_error!)),
            ),
          )
        : _items.isEmpty
        ? const AppEmptyState(
            icon: Icons.markunread_mailbox_outlined,
            title: 'Chưa có yêu cầu tin nhắn',
            message: 'Tin nhắn từ người chưa kết bạn sẽ xuất hiện ở đây.',
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final peer = item.peer;
                final url = peer.avatar?.trim() ?? '';
                return ListTile(
                  leading: BounceTap(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PublicProfileScreen(
                            userId: peer.userId,
                            authNotifier: widget.authNotifier,
                          ),
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.surfaceStrong,
                        child: url.isEmpty
                            ? const Icon(Icons.person_outline)
                            : ClipOval(
                                child: Image.network(
                                  url,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.person_outline),
                                ),
                              ),
                      ),
                    ),
                  ),
                  title: Text(_name(item)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.lastMessage?.content ?? 'Yêu cầu tin nhắn mới',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.lastMessage?.createdAt != null ||
                          item.updatedAt != null)
                        Text(
                          MessagingDateTime.format(
                            item.lastMessage?.createdAt ?? item.updatedAt!,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.unreadCount > 0)
                        Badge(label: Text('${item.unreadCount}')),
                      PopupMenuButton<String>(
                        tooltip: 'Tùy chọn',
                        onSelected: (value) => _manage(item, value),
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
  );
}
