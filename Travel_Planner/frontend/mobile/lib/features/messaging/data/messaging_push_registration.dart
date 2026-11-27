import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/network/api_client.dart';

class MessagingPushRegistration {
  MessagingPushRegistration({
    ApiClient? apiClient,
    FirebaseMessaging? messaging,
  }) : _api = apiClient ?? ApiClient(),
       _messaging = messaging ?? FirebaseMessaging.instance;

  static final MessagingPushRegistration shared = MessagingPushRegistration();

  static const String _endpoint = '/api/users/me/devices/fcm-token';
  final ApiClient _api;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _sessionToken;
  String? _registeredToken;
  bool _sessionInitialized = false;

  Future<void> syncSession(
    String? sessionToken, {
    void Function(RemoteMessage message)? onNotificationTap,
    void Function(RemoteMessage message)? onForegroundMessage,
  }) async {
    if (sessionToken == null || sessionToken.isEmpty) {
      await _tokenSubscription?.cancel();
      await _openedSubscription?.cancel();
      await _foregroundSubscription?.cancel();
      _tokenSubscription = null;
      _openedSubscription = null;
      _foregroundSubscription = null;
      _sessionToken = null;
      _registeredToken = null;
      _sessionInitialized = false;
      return;
    }

    if (_sessionToken == sessionToken && _sessionInitialized) return;
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _sessionToken = sessionToken;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      _sessionInitialized = true;
      return;
    }

    // Direct FID registration currently returns SERVICE_NOT_AVAILABLE on the
    // supported Android devices, so retain the compatible FCM token transport.
    // ignore: deprecated_member_use
    _tokenSubscription = _messaging.onTokenRefresh.listen((fcmToken) {
      unawaited(_register(fcmToken, sessionToken));
    });
    // ignore: deprecated_member_use
    final fcmToken = await _messaging.getToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      throw StateError('Firebase Messaging không trả về registration token.');
    }
    await _register(fcmToken, sessionToken);

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      onNotificationTap?.call(message);
    });
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) onNotificationTap?.call(initialMessage);
    _sessionInitialized = true;
  }

  Future<void> unregisterBeforeLogout(String sessionToken) async {
    final fcmToken = _registeredToken;
    if (fcmToken == null || fcmToken.isEmpty) return;
    try {
      await _api.delete(
        _endpoint,
        token: sessionToken,
        body: {'token': fcmToken, 'platform': 'ANDROID'},
      );
      // ignore: deprecated_member_use
      await _messaging.deleteToken();
    } finally {
      await _tokenSubscription?.cancel();
      await _openedSubscription?.cancel();
      await _foregroundSubscription?.cancel();
      _tokenSubscription = null;
      _openedSubscription = null;
      _foregroundSubscription = null;
      _sessionToken = null;
      _registeredToken = null;
      _sessionInitialized = false;
    }
  }

  Future<void> _register(String fcmToken, String sessionToken) async {
    if (_sessionToken != sessionToken) return;
    await _api.put(
      _endpoint,
      token: sessionToken,
      body: {'token': fcmToken, 'platform': 'ANDROID'},
    );
    _registeredToken = fcmToken;
  }
}
