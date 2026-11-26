import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_notifier.dart';
import 'package:mobile/core/sync/app_sync_bus.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/presentation/notification_unread_count_notifier.dart';
import 'package:mobile/features/notifications/presentation/widgets/notification_bell_button.dart';

void main() {
  testWidgets(
    'shows the unread total and refreshes on navigation invalidation',
    (tester) async {
      final repository = _SequenceNotificationRepository([2, 5]);
      final countNotifier = NotificationUnreadCountNotifier(
        repository: repository,
      );
      final authNotifier = _TestAuthNotifier('test-token', 'user-1');
      await countNotifier.refresh('user-1', 'test-token');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBellButton(
              authNotifier: authNotifier,
              countNotifier: countNotifier,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(repository.requestCount, 1);

      AppSyncBus.requestRefresh(SyncDomain.notifications);
      await tester.pump();

      expect(repository.requestCount, 2);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      authNotifier.dispose();
      countNotifier.dispose();
    },
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._token, this._userId);

  final String _token;
  final String _userId;

  @override
  String? get token => _token;

  @override
  Map<String, dynamic>? get currentUser => {'userId': _userId};
}

class _SequenceNotificationRepository extends NotificationRepository {
  _SequenceNotificationRepository(this._counts);

  final List<int> _counts;
  int requestCount = 0;

  @override
  Future<int> getUnreadCount(String token) async {
    final index = requestCount++;
    return _counts[index < _counts.length ? index : _counts.length - 1];
  }
}
