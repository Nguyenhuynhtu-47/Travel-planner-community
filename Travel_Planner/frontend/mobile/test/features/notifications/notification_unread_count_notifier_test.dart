import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/presentation/notification_unread_count_notifier.dart';

void main() {
  test('coalesces unread count requests from multiple mounted bells', () async {
    final repository = _DelayedNotificationRepository();
    final notifier = NotificationUnreadCountNotifier(repository: repository);

    final first = notifier.refresh('user-1', 'token-1');
    final second = notifier.refresh('user-1', 'token-1');

    expect(repository.requestCount, 1);
    repository.response.complete(6);
    await Future.wait([first, second]);

    expect(notifier.count, 6);
    expect(notifier.accountKey, 'user-1');
    notifier.dispose();
  });

  test('clears the previous account count on account switch', () async {
    final repository = _DelayedNotificationRepository();
    final notifier = NotificationUnreadCountNotifier(repository: repository);

    final first = notifier.refresh('user-1', 'token-1');
    repository.response.complete(8);
    await first;
    final nextResponse = Completer<int>();
    repository.nextResponse = nextResponse;

    final second = notifier.refresh('user-2', 'token-2');
    expect(notifier.accountKey, 'user-2');
    expect(notifier.count, 0);
    nextResponse.complete(2);
    await second;
    expect(notifier.count, 2);
    notifier.dispose();
  });
}

class _DelayedNotificationRepository extends NotificationRepository {
  int requestCount = 0;
  Completer<int> response = Completer<int>();
  Completer<int>? nextResponse;

  @override
  Future<int> getUnreadCount(String token) {
    requestCount++;
    final pending = nextResponse;
    if (pending != null) {
      nextResponse = null;
      return pending.future;
    }
    return response.future;
  }
}
