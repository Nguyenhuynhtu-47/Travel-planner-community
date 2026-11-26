import 'package:flutter/foundation.dart';

import '../data/notification_repository.dart';

/// Shares the authoritative personal unread total across mounted bell buttons.
///
/// Main navigation keeps its tabs alive in an IndexedStack, so each bell must
/// not independently poll the count endpoint on app start or invalidation.
class NotificationUnreadCountNotifier extends ChangeNotifier {
  static final NotificationUnreadCountNotifier shared =
      NotificationUnreadCountNotifier();

  final NotificationRepository _repository;
  NotificationUnreadCountNotifier({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  String? _accountKey;
  int _count = 0;
  DateTime? _loadedAt;
  final Map<String, Future<void>> _inFlightByAccount = {};

  int get count => _count;
  String? get accountKey => _accountKey;

  Future<void> refresh(String accountKey, String token, {bool force = false}) {
    if (_accountKey != accountKey) {
      _accountKey = accountKey;
      _count = 0;
      _loadedAt = null;
      notifyListeners();
    }
    final inFlight = _inFlightByAccount[accountKey];
    if (inFlight != null) return inFlight;
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30)) {
      return Future<void>.value();
    }

    final pending = _repository.getUnreadCount(token).then((count) {
      if (_accountKey == accountKey) {
        _count = count;
        _loadedAt = DateTime.now();
        notifyListeners();
      }
    });
    _inFlightByAccount[accountKey] = pending;
    return pending.whenComplete(() {
      if (identical(_inFlightByAccount[accountKey], pending)) {
        _inFlightByAccount.remove(accountKey);
      }
    });
  }

  void clear() {
    if (_accountKey == null && _count == 0) return;
    _accountKey = null;
    _count = 0;
    _loadedAt = null;
    notifyListeners();
  }
}
