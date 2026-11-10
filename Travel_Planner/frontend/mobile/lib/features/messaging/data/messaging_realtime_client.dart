import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/constants/api_constants.dart';
import 'models/chat_event.dart';

enum RealtimeStatus { disconnected, connecting, connected }

class MessagingRealtimeClient {
  static final MessagingRealtimeClient shared = MessagingRealtimeClient();

  final _events = StreamController<ChatEvent>.broadcast();
  final _status = StreamController<RealtimeStatus>.broadcast();
  StompClient? _client;
  StompUnsubscribe? _subscription;
  Timer? _expiryTimer;
  Timer? _reconnectTimer;
  String? _token;
  String? _accountKey;
  bool _disposed = false;
  bool _intentionalDisconnect = false;
  bool _replacingSocket = false;
  int _reconnectAttempt = 0;
  RealtimeStatus _current = RealtimeStatus.disconnected;

  Stream<ChatEvent> get events => _events.stream;
  Stream<RealtimeStatus> get statuses => _status.stream;
  RealtimeStatus get currentStatus => _current;

  void connect(String token, String accountKey) {
    if (_disposed ||
        (_token == token &&
            _accountKey == accountKey &&
            _client?.isActive == true)) {
      return;
    }
    disconnect();
    _intentionalDisconnect = false;
    _token = token;
    _accountKey = accountKey;
    final expiry = _tokenExpiry(token);
    if (expiry == null || !expiry.isAfter(DateTime.now())) {
      _token = null;
      _accountKey = null;
      _setStatus(RealtimeStatus.disconnected);
      return;
    }
    _expiryTimer = Timer(expiry.difference(DateTime.now()), disconnect);
    _openSocket();
  }

  void _openSocket() {
    final token = _token;
    if (_disposed || token == null) return;
    _setStatus(RealtimeStatus.connecting);
    final base = Uri.parse(ApiConstants.baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final url = base
        .replace(scheme: scheme, path: '${base.path}/ws')
        .toString();
    late final StompClient client;
    client = StompClient(
      config: StompConfig(
        url: url,
        reconnectDelay: Duration.zero,
        heartbeatIncoming: const Duration(seconds: 20),
        heartbeatOutgoing: const Duration(seconds: 20),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (_) {
          if (_disposed || client != _client) return;
          _reconnectAttempt = 0;
          _setStatus(RealtimeStatus.connected);
          _subscription = client.subscribe(
            destination: '/user/queue/chat-events',
            callback: (frame) {
              final body = frame.body;
              if (body == null || body.isEmpty) return;
              try {
                final data = jsonDecode(body);
                if (data is Map<String, dynamic>) {
                  _events.add(ChatEvent.fromJson(data));
                }
              } catch (_) {
                // REST is the source of truth when a realtime frame is invalid.
              }
            },
          );
        },
        onDisconnect: (_) => _scheduleReconnect(),
        onStompError: (_) => _scheduleReconnect(),
        onWebSocketError: (_) => _scheduleReconnect(),
        onWebSocketDone: _scheduleReconnect,
      ),
    );
    _client = client;
    client.activate();
  }

  void _scheduleReconnect() {
    if (_disposed ||
        _intentionalDisconnect ||
        _replacingSocket ||
        _token == null ||
        _reconnectTimer != null) {
      return;
    }
    _setStatus(RealtimeStatus.disconnected);
    final seconds = 1 << _reconnectAttempt.clamp(0, 5);
    final delay = Duration(seconds: seconds.clamp(1, 30));
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _replacingSocket = true;
      _subscription?.call();
      _subscription = null;
      _client?.deactivate();
      _client = null;
      _replacingSocket = false;
      _openSocket();
    });
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _subscription?.call();
    _subscription = null;
    _client?.deactivate();
    _client = null;
    _token = null;
    _accountKey = null;
    _setStatus(RealtimeStatus.disconnected);
  }

  DateTime? _tokenExpiry(String value) {
    try {
      final parts = value.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round());
    } catch (_) {
      return null;
    }
  }

  void _setStatus(RealtimeStatus value) {
    _current = value;
    if (!_status.isClosed) _status.add(value);
  }

  Future<void> dispose() async {
    _disposed = true;
    disconnect();
    await _events.close();
    await _status.close();
  }
}
