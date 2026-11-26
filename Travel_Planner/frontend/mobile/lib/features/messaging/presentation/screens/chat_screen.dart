import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../data/messaging_date_time.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/chat_event.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/conversation_summary.dart';
import '../widgets/share_message_card.dart';

class ChatScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MessagingRepository repository;
  final MessagingRealtimeClient? realtime;
  final ConversationSummary conversation;
  final String? initialSystemNotice;
  const ChatScreen({
    super.key,
    required this.authNotifier,
    required this.repository,
    this.realtime,
    required this.conversation,
    this.initialSystemNotice,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  late final String? _initialSystemNotice = widget.initialSystemNotice;
  bool _loading = true,
      _loadingOlder = false,
      _sending = false,
      _messageRequestBusy = false,
      _requestAccepted = false,
      _blockingPeer = false,
      _unblockingPeer = false,
      _blockedPeer = false,
      _blockStateLoaded = false,
      _hasMore = false;
  bool? _canSendOverride;
  late String _conversationStatus;
  late bool _recipientPrivacyRestricted;
  late bool _canRespondToMessageRequest;
  int? _before;
  String? _error;
  int _peerReadSequence = 0;
  RealtimeStatus _realtimeStatus = RealtimeStatus.disconnected;
  late final StreamSubscription<ChatEvent> _eventSubscription;
  late final StreamSubscription<RealtimeStatus> _statusSubscription;
  late final int _me;
  late final MessagingRealtimeClient _realtime =
      widget.realtime ?? MessagingRealtimeClient.shared;

  bool get _canSendMessage =>
      (_canSendOverride ?? widget.conversation.canSendMessage) &&
      !_blockedPeer &&
      _blockStateLoaded;
  bool get _isPending => _conversationStatus == 'PENDING' && !_requestAccepted;
  @override
  void initState() {
    super.initState();
    _conversationStatus = widget.conversation.status;
    _recipientPrivacyRestricted =
        widget.conversation.recipientPrivacyRestricted;
    _canRespondToMessageRequest =
        widget.conversation.canRespondToMessageRequest;
    _me =
        int.tryParse('${widget.authNotifier.currentUser?['userId'] ?? ''}') ??
        -1;
    widget.authNotifier.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    _realtimeStatus = _realtime.currentStatus;
    _eventSubscription = _realtime.events.listen(_onEvent);
    _statusSubscription = _realtime.statuses.listen((status) {
      if (mounted) setState(() => _realtimeStatus = status);
      if (status == RealtimeStatus.connected) _syncNewMessages();
    });
    if (widget.conversation.conversationId > 0 &&
        widget.authNotifier.token != null &&
        _realtime.currentStatus != RealtimeStatus.connected) {
      _realtime.connect(widget.authNotifier.token!, "$_me");
    }
    if (widget.conversation.conversationId > 0 &&
        widget.initialSystemNotice == null) {
      _load();
      _refreshBlockState();
    } else {
      _blockStateLoaded = true;
    }
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.authNotifier.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription.cancel();
    _statusSubscription.cancel();
    _input.dispose();
    _scroll.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await widget.repository.messages(
        widget.conversation.conversationId,
        widget.authNotifier.token!,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(p.content);
        _hasMore = p.hasMore;
        _before = p.nextBeforeSequence;
        _peerReadSequence = p.peerReadSequence ?? 0;
        _loading = false;
      });
      if (_messages.isNotEmpty && !_isPending) {
        _markRead(_messages.last.sequenceNumber);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không thể tải tin nhắn. Hãy thử tải lại.';
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels < 100) _loadOlder();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _before == null) return;
    final oldPixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;
    final oldExtent = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0.0;
    setState(() => _loadingOlder = true);
    try {
      final p = await widget.repository.messages(
        widget.conversation.conversationId,
        widget.authNotifier.token!,
        beforeSequence: _before,
      );
      if (mounted) {
        setState(() {
          _merge(p.content);
          _hasMore = p.hasMore;
          _before = p.nextBeforeSequence;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(
              oldPixels + _scroll.position.maxScrollExtent - oldExtent,
            );
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingOlder = false);
  }

  void _authChanged() {
    final currentId = '${widget.authNotifier.currentUser?['userId'] ?? ''}';
    if (!widget.authNotifier.isAuthenticated ||
        int.tryParse(currentId) != _me) {
      _messages.clear();
      _input.clear();
      if (mounted) Navigator.of(context).maybePop();
    } else if (mounted) {
      // Profile updates notify AuthNotifier even when the account ID is unchanged.
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncNewMessages();
      _refreshBlockState();
    }
  }

  Future<void> _refreshBlockState() async {
    final token = widget.authNotifier.token;
    if (token == null || widget.conversation.conversationId <= 0) {
      if (mounted) setState(() => _blockStateLoaded = true);
      return;
    }
    try {
      var page = 0;
      var blocked = false;
      while (page < 100) {
        final result = await widget.repository.blockedUsers(token, page: page);
        if (result.content.any(
          (user) => user.userId == widget.conversation.peer.userId,
        )) {
          blocked = true;
          break;
        }
        if (result.isLast) break;
        page++;
      }
      if (mounted) {
        setState(() {
          _blockedPeer = blocked;
          if (blocked) _canSendOverride = false;
          _blockStateLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _blockStateLoaded = true);
    }
  }

  Future<void> _syncNewMessages() async {
    if (!mounted ||
        widget.conversation.conversationId <= 0 ||
        widget.authNotifier.token == null) {
      return;
    }
    try {
      final page = await widget.repository.messages(
        widget.conversation.conversationId,
        widget.authNotifier.token!,
        afterSequence: _messages
            .where((m) => m.messageId != null)
            .fold<int>(
              0,
              (v, m) => m.sequenceNumber > v ? m.sequenceNumber : v,
            ),
      );
      if (!mounted) return;
      if (page.content.isNotEmpty) {
        setState(() {
          _merge(page.content);
          _peerReadSequence = page.peerReadSequence ?? _peerReadSequence;
        });
        if (!_isPending) _markRead(page.content.last.sequenceNumber);
      }
    } catch (_) {}
  }

  void _onEvent(ChatEvent event) {
    if (event.type == 'CONVERSATION_ACCESS_REVOKED' &&
        mounted &&
        event.blockedUserId == _me &&
        event.blockedByUserId == widget.conversation.peer.userId) {
      _messages.clear();
      _input.clear();
      if (mounted) {
        setState(() => _error = 'Bạn không thể xem cuộc trò chuyện này.');
        Navigator.of(context).maybePop();
      }
      return;
    }
    if (!mounted ||
        event.conversationId != widget.conversation.conversationId) {
      return;
    }
    if (event.type == 'MESSAGE_REQUEST_ACCEPTED') {
      setState(() {
        _requestAccepted = true;
        _conversationStatus = 'ACCEPTED';
        _canRespondToMessageRequest = false;
        _canSendOverride = true;
      });
      return;
    }
    if (event.type == 'READ_CURSOR_UPDATED' &&
        event.readerUserId != _me &&
        event.sequenceNumber != null) {
      setState(
        () => _peerReadSequence = max(_peerReadSequence, event.sequenceNumber!),
      );
      return;
    }
    if (event.message != null) {
      if (_blockedPeer && event.message!.senderUserId != _me) return;
      setState(() {
        _merge([event.message!]);
      });
      if (event.message!.senderUserId != _me && !_isPending) {
        _markRead(event.message!.sequenceNumber);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    }
  }

  void _merge(List<ChatMessage> incoming) {
    for (final message in incoming) {
      final i = _messages.indexWhere(
        (m) =>
            (message.messageId != null && m.messageId == message.messageId) ||
            m.clientMessageId == message.clientMessageId,
      );
      if (i >= 0) {
        _messages[i] = message;
      } else {
        _messages.add(message);
      }
    }
    _messages.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
  }

  Future<void> _markRead(int sequence) async {
    try {
      await widget.repository.markRead(
        widget.conversation.conversationId,
        sequence,
        widget.authNotifier.token!,
      );
    } catch (_) {}
  }

  void _scrollBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  String _uuid() {
    final r = Random.secure();
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> _send({String? retryId}) async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !_canSendMessage) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    final id = retryId ?? _uuid();
    final existing = _messages.indexWhere((m) => m.clientMessageId == id);
    if (existing < 0) {
      _messages.add(
        ChatMessage(
          messageId: null,
          conversationId: widget.conversation.conversationId,
          sequenceNumber: 1 << 30,
          senderUserId: _me,
          senderName: '${widget.authNotifier.currentUser?['fullName'] ?? ''}',
          clientMessageId: id,
          content: text,
          createdAt: DateTime.now(),
          sending: true,
        ),
      );
    } else {
      _messages[existing] = _messages[existing].copyWith(
        sending: true,
        failed: false,
      );
    }
    setState(() {
      _sending = true;
      _input.clear();
    });
    _scrollBottom();
    try {
      final sent = await widget.repository.send(
        widget.conversation.conversationId,
        id,
        text,
        token,
      );
      if (mounted) {
        setState(() {
          _merge([sent]);
          if (sent.conversationStatus != null) {
            _conversationStatus = sent.conversationStatus!;
          }
          if (!sent.recipientVisible) _recipientPrivacyRestricted = true;
          if (sent.conversationStatus == 'ACCEPTED') {
            _requestAccepted = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        final i = _messages.indexWhere((m) => m.clientMessageId == id);
        if (i >= 0) {
          setState(
            () => _messages[i] = _messages[i].copyWith(
              sending: false,
              failed: true,
            ),
          );
        }
        _input.text = text;
        AppToast.showError(
          context,
          'Gửi chưa thành công. Bạn có thể nhấn thử gửi lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _messageAvatar(ChatMessage message) {
    final isOwn = message.senderUserId == _me;
    final ownAvatar = widget.authNotifier.currentUser?['avatar']?.toString();
    final avatar = isOwn
        ? ownAvatar
        : (message.senderAvatar?.trim().isNotEmpty == true
              ? message.senderAvatar!.trim()
              : widget.conversation.peer.avatar);
    return _avatarFromUrl(avatar, size: 28);
  }

  Widget _avatarFromUrl(String? url, {required double size}) {
    final imageUrl = url?.trim();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceStrong,
      child: imageUrl?.isNotEmpty == true
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _avatarPlaceholder(),
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person_outline,
                  size: 17,
                  color: AppColors.muted,
                ),
              ),
            )
          : _avatarPlaceholder(),
    );
  }

  Widget _avatarPlaceholder() =>
      const Icon(Icons.person_outline, size: 17, color: AppColors.muted);

  bool _sameVisualGroup(int first, int second) {
    if (first < 0 || second >= _messages.length) return false;
    final a = _messages[first];
    final b = _messages[second];
    if (a.senderUserId != b.senderUserId) return false;
    final aTime = MessagingDateTime.toVietnamTime(a.createdAt);
    final bTime = MessagingDateTime.toVietnamTime(b.createdAt);
    if (aTime.year != bTime.year ||
        aTime.month != bTime.month ||
        aTime.day != bTime.day) {
      return false;
    }
    return bTime.difference(aTime).abs() <= const Duration(minutes: 2);
  }

  Widget _buildMessageRow(BuildContext context, int messageIndex) {
    final message = _messages[messageIndex];
    final own = message.senderUserId == _me;
    final startsGroup = !_sameVisualGroup(messageIndex - 1, messageIndex);
    final endsGroup = !_sameVisualGroup(messageIndex, messageIndex + 1);
    const avatarSize = 28.0;
    const avatarGap = 8.0;
    final rowWidth = MediaQuery.sizeOf(context).width - 24;
    final maxBubbleWidth = min(
      rowWidth * .78,
      rowWidth - avatarSize - avatarGap,
    ).clamp(0.0, rowWidth).toDouble();

    final Widget bubbleContent;
    if (message.isShare) {
      bubbleContent = ShareMessageCard(
        message: message,
        isOwn: own,
        authNotifier: widget.authNotifier,
        peerReadSequence: _peerReadSequence,
        onRetry: () => _send(retryId: message.clientMessageId),
      );
    } else {
      bubbleContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: own ? AppColors.primaryLight : AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.displayContent),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                MessagingDateTime.format(message.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            if (message.failed)
              TextButton(
                onPressed: () => _send(retryId: message.clientMessageId),
                child: const Text('Thử gửi lại'),
              )
            else if (message.sending)
              const Text('Đang gửi…', style: TextStyle(fontSize: 10))
            else if (own &&
                message.recipientVisible &&
                message.sequenceNumber <= _peerReadSequence)
              const Text('Đã đọc', style: TextStyle(fontSize: 10))
            else if (own && message.recipientVisible && message.messageId != null)
              const Text('Đã gửi', style: TextStyle(fontSize: 10)),
          ],
        ),
      );
    }

    final avatarSlot = SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: endsGroup ? _messageAvatar(message) : null,
    );
    final children = own
        ? <Widget>[
            Flexible(child: bubbleContent),
            const SizedBox(width: avatarGap),
            avatarSlot,
          ]
        : <Widget>[
            avatarSlot,
            const SizedBox(width: avatarGap),
            Flexible(child: bubbleContent),
          ];

    return Padding(
      key: ValueKey(message.clientMessageId),
      padding: EdgeInsets.only(top: startsGroup ? 7 : 1, bottom: 1),
      child: Row(
        mainAxisAlignment: own
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: children,
      ),
    );
  }

  Future<void> _openPeerProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          userId: widget.conversation.peer.userId,
          authNotifier: widget.authNotifier,
        ),
      ),
    );
  }

  Future<void> _blockPeer() async {
    if (_blockedPeer || _blockingPeer) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chặn người dùng?'),
        content: Text(
          'Bạn sẽ không thể nhắn tin hoặc kết bạn với ${widget.conversation.peer.fullName?.trim().isNotEmpty == true ? widget.conversation.peer.fullName : '@${widget.conversation.peer.effectiveHandle}'}. Lịch sử trò chuyện vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chặn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() => _blockingPeer = true);
    try {
      await widget.repository.block(widget.conversation.peer.userId, token);
      if (mounted) {
        setState(() {
          _blockedPeer = true;
          _canSendOverride = false;
        });
        AppToast.showSuccess(context, 'Đã chặn người dùng.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể chặn người dùng lúc này.');
      }
    } finally {
      if (mounted) setState(() => _blockingPeer = false);
    }
  }

  Future<void> _unblockPeer() async {
    if (!_blockedPeer || _unblockingPeer) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ chặn người dùng?'),
        content: const Text(
          'Sau khi bỏ chặn, hai bên có thể nhắn tin theo cài đặt quyền riêng tư hiện tại. Lịch sử trò chuyện vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Giữ chặn'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bỏ chặn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() => _unblockingPeer = true);
    try {
      await widget.repository.unblock(widget.conversation.peer.userId, token);
      final current = widget.conversation.conversationId > 0
          ? await widget.repository.openDirect(
              widget.conversation.peer.userId,
              token,
            )
          : null;
      if (mounted) {
        setState(() {
          _blockedPeer = false;
          if (current != null) _canSendOverride = current.canSendMessage;
        });
        AppToast.showSuccess(context, 'Đã bỏ chặn người dùng.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, 'Không thể bỏ chặn người dùng lúc này.');
      }
    } finally {
      if (mounted) setState(() => _unblockingPeer = false);
    }
  }

  void _handleChatAction(String action) {
    if (action == 'profile') _openPeerProfile();
    if (action == 'block') _blockPeer();
    if (action == 'unblock') _unblockPeer();
  }

  Future<void> _respondToMessageRequest({required bool accept}) async {
    if (_messageRequestBusy || !_canRespondToMessageRequest) {
      return;
    }
    final token = widget.authNotifier.token;
    if (token == null) return;
    setState(() => _messageRequestBusy = true);
    try {
      if (accept) {
        final accepted = await widget.repository.acceptMessageRequest(
          widget.conversation.conversationId,
          token,
        );
        if (mounted) {
          setState(() {
            _requestAccepted = true;
            _conversationStatus = accepted.status;
            _canRespondToMessageRequest = false;
            _canSendOverride = accepted.canSendMessage;
          });
        }
      } else {
        await widget.repository.declineMessageRequest(
          widget.conversation.conversationId,
          token,
        );
      }
      if (!accept && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Không thể cập nhật yêu cầu tin nhắn. Hãy tải lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _messageRequestBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.conversation.peer;
    final title = peer.fullName?.trim().isNotEmpty == true
        ? peer.fullName!
        : '@${peer.effectiveHandle}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _avatarFromUrl(peer.avatar, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn cuộc trò chuyện',
            onSelected: _handleChatAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline),
                  title: Text('Xem trang cá nhân'),
                ),
              ),
              PopupMenuItem(
                value: _blockedPeer ? 'unblock' : 'block',
                enabled:
                    _blockStateLoaded && !_blockingPeer && !_unblockingPeer,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_blockedPeer ? Icons.lock_open : Icons.block),
                  title: Text(
                    _blockedPeer
                        ? _unblockingPeer
                              ? 'Đang bỏ chặn…'
                              : 'Bỏ chặn người dùng'
                        : !_blockStateLoaded
                        ? 'Đang kiểm tra trạng thái…'
                        : _blockingPeer
                        ? 'Đang chặn…'
                        : 'Chặn người dùng',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_realtimeStatus != RealtimeStatus.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppColors.surface,
              child: Text(switch (_realtimeStatus) {
                RealtimeStatus.connecting => 'Đang kết nối chat…',
                RealtimeStatus.reconnecting =>
                  'Kết nối gián đoạn · đang thử kết nối lại…',
                RealtimeStatus.failed => 'Phiên realtime không hợp lệ hoặc đã hết hạn. Hãy đăng nhập lại.',
                RealtimeStatus.disconnected => 'Realtime đang ngoại tuyến · lịch sử vẫn được đồng bộ từ máy chủ.',
                RealtimeStatus.connected => '',
              }),
            ),
          if (_isPending && _canRespondToMessageRequest)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surfaceSoft,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _messageRequestBusy
                            ? null
                            : () => _respondToMessageRequest(accept: false),
                        child: const Text('Từ chối'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _messageRequestBusy
                            ? null
                            : () => _respondToMessageRequest(accept: true),
                        child: const Text('Chấp nhận'),
                      ),
                    ],
                  );
                  const label = Text('Yêu cầu tin nhắn từ người chưa kết bạn');
                  if (constraints.maxWidth < 340) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      const Expanded(child: label),
                      actions,
                    ],
                  );
                },
              ),
            ),
          if (_isPending &&
              !_canRespondToMessageRequest &&
              widget.conversation.canSendMessage)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surfaceSoft,
              child: Text(
                _recipientPrivacyRestricted
                    ? 'Người này chỉ nhận tin nhắn từ bạn bè. Tin nhắn bạn gửi chỉ hiển thị với bạn; nếu kết bạn sau này, các tin cũ vẫn không được chuyển.'
                    : 'Tin nhắn của bạn đang ở mục Tin nhắn người lạ. Bạn có thể gửi thêm; khi người nhận trả lời, cuộc trò chuyện chuyển vào hộp thư chính.',
              ),
            ),
          if (_blockedPeer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.surfaceSoft,
              child: const Text(
                'Bạn đã chặn người dùng này. Lịch sử vẫn được giữ.',
              ),
            ),
          if (!_canSendMessage)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Text(
                _initialSystemNotice ??
                    (_isPending &&
                            !_canRespondToMessageRequest &&
                            widget.conversation.lastMessageSequence == 0
                        ? 'Người này hiện không nhận tin nhắn từ người chưa kết bạn. Hãy kết bạn hoặc thay đổi cài đặt quyền riêng tư để bắt đầu trò chuyện.'
                        : widget.conversation.status == 'DECLINED' &&
                              widget.conversation.requestAvailableAt != null
                        ? 'Yêu cầu đã bị từ chối. Bạn có thể gửi lại sau ${MessagingDateTime.format(widget.conversation.requestAvailableAt!)}.'
                        : 'Bạn hiện không thể gửi tin nhắn trong cuộc trò chuyện này.'),
              ),
            ),
          Expanded(
            child: _initialSystemNotice != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _initialSystemNotice,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      child: Text(_error!),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loadingOlder && index == 0) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messageIndex = index - (_loadingOlder ? 1 : 0);
                      return _buildMessageRow(context, messageIndex);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 5,
                      enabled: _canSendMessage,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending || !_canSendMessage ? null : _send,
                    icon: const Icon(Icons.send),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
