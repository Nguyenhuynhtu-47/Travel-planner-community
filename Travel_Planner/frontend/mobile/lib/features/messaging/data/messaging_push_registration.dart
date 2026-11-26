import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/network/api_client.dart';

class MessagingPushRegistration {
  MessagingPushRegistration({ApiClient? apiClient, FirebaseMessaging? messaging})
    : _api = apiClient ?? ApiClient(),
      _messaging = messaging ?? FirebaseMessaging.instance;

  static final MessagingPushRegistration shared = MessagingPushRegistration();

  static const String _endpoint = '/api/users/me/devices/fcm-token';
  final ApiClient _api;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _sessionToken;
  String? _registeredInstallationId;
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
      _registeredInstallationId = null;
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

    _tokenSubscription = _messaging.onRegistered.listen((installationId) {
      unawaited(_register(installationId, sessionToken));
    });
    await _messaging.register();

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
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
    final installationId = _registeredInstallationId;
    if (installationId == null || installationId.isEmpty) return;
    try {
      await _api.delete(
        _endpoint,
        token: sessionToken,
        body: {'token': installationId, 'platform': 'ANDROID'},
      );
      await _messaging.unregister();
    } finally {
      await _tokenSubscription?.cancel();
      await _openedSubscription?.cancel();
      await _foregroundSubscription?.cancel();
      _tokenSubscription = null;
      _openedSubscription = null;
      _foregroundSubscription = null;
      _sessionToken = null;
      _registeredInstallationId = null;
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
    _registeredInstallationId = fcmToken;
  }
}
