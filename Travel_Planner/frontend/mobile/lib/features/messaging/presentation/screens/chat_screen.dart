import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_notifier.dart';
import '../../data/messaging_repository.dart';
import '../../data/messaging_realtime_client.dart';
import '../../data/models/chat_event.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/conversation_summary.dart';

class ChatScreen extends StatefulWidget {
  final AuthNotifier authNotifier;
  final MessagingRepository repository;
  final MessagingRealtimeClient? realtime;
  final ConversationSummary conversation;
  const ChatScreen({
    super.key,
    required this.authNotifier,
    required this.repository,
    this.realtime,
    required this.conversation,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = true,
      _loadingOlder = false,
      _sending = false,
      _hasMore = false;
  int? _before;
  String? _error;
  int _peerReadSequence = 0;
  RealtimeStatus _realtimeStatus = RealtimeStatus.disconnected;
  late final StreamSubscription<ChatEvent> _eventSubscription;
  late final StreamSubscription<RealtimeStatus> _statusSubscription;
  late final int _me;
  late final MessagingRealtimeClient _realtime =
      widget.realtime ?? MessagingRealtimeClient.shared;
  @override
  void initState() {
    super.initState();
    _me =
        int.tryParse('${widget.authNotifier.currentUser?['userId'] ?? ''}') ??
        -1;
    widget.authNotifier.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    _eventSubscription = _realtime.events.listen(_onEvent);
    _statusSubscription = _realtime.statuses.listen((status) {
      if (mounted) setState(() => _realtimeStatus = status);
      if (status == RealtimeStatus.connected) _syncNewMessages();
    });
    if (widget.authNotifier.token != null &&
        _realtime.currentStatus != RealtimeStatus.connected)
      _realtime.connect(widget.authNotifier.token!, "$_me");
    _load();
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
      if (_messages.isNotEmpty) _markRead(_messages.last.sequenceNumber);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Không thể tải tin nhắn. Hãy thử tải lại.';
        });
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
          if (_scroll.hasClients)
            _scroll.jumpTo(
              oldPixels + _scroll.position.maxScrollExtent - oldExtent,
            );
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
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncNewMessages();
  }

  Future<void> _syncNewMessages() async {
    if (!mounted || _messages.isEmpty || widget.authNotifier.token == null)
      return;
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
        _markRead(page.content.last.sequenceNumber);
      }
    } catch (_) {}
  }

  void _onEvent(ChatEvent event) {
    if (event.conversationId != widget.conversation.conversationId || !mounted)
      return;
    if (event.type == 'READ_CURSOR_UPDATED' &&
        event.readerUserId != _me &&
        event.sequenceNumber != null) {
      setState(
        () => _peerReadSequence = max(_peerReadSequence, event.sequenceNumber!),
      );
      return;
    }
    if (event.message != null) {
      setState(() => _merge([event.message!]));
      if (event.message!.senderUserId != _me)
        _markRead(event.message!.sequenceNumber);
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
    if (_scroll.hasClients)
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
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
    if (text.isEmpty || _sending || !widget.conversation.canSendMessage) return;
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
      if (mounted) setState(() => _merge([sent]));
    } catch (_) {
      if (mounted) {
        final i = _messages.indexWhere((m) => m.clientMessageId == id);
        if (i >= 0)
          setState(
            () => _messages[i] = _messages[i].copyWith(
              sending: false,
              failed: true,
            ),
          );
        _input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gửi chưa thành công. Bạn có thể nhấn thử gửi lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (_realtimeStatus != RealtimeStatus.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppColors.surface,
              child: Text(
                _realtimeStatus == RealtimeStatus.connecting
                    ? 'Đang kết nối chat…'
                    : 'Mất kết nối realtime · đang chờ đồng bộ',
              ),
            ),
          if (!widget.conversation.canSendMessage)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: const Text(
                'Bạn hiện không thể gửi tin nhắn trong cuộc trò chuyện này.',
              ),
            ),
          Expanded(
            child: _loading
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
                      if (_loadingOlder && index == 0)
                        return const Center(child: CircularProgressIndicator());
                      final message =
                          _messages[index - (_loadingOlder ? 1 : 0)];
                      final own = message.senderUserId == _me;
                      return Align(
                        alignment: own
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .78,
                          ),
                          decoration: BoxDecoration(
                            color: own
                                ? AppColors.primaryLight
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(message.content),
                              if (message.failed)
                                TextButton(
                                  onPressed: () =>
                                      _send(retryId: message.clientMessageId),
                                  child: const Text('Thử gửi lại'),
                                )
                              else if (message.sending)
                                const Text(
                                  'Đang gửi…',
                                  style: TextStyle(fontSize: 10),
                                )
                              else if (own &&
                                  message.sequenceNumber <= _peerReadSequence)
                                const Text(
                                  'Đã đọc',
                                  style: TextStyle(fontSize: 10),
                                )
                              else if (own && message.messageId != null)
                                const Text(
                                  'Đã gửi',
                                  style: TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      );
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
                      enabled: widget.conversation.canSendMessage,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
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
