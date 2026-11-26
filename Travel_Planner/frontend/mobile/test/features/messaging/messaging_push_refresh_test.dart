import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messaging/data/messaging_realtime_client.dart';
import 'package:mobile/features/messaging/data/models/chat_event.dart';

void main() {
  test('foreground FCM hint refreshes only a valid conversation id', () async {
    final realtime = MessagingRealtimeClient();
    final received = expectLater(
      realtime.events,
      emits(
        predicate<ChatEvent>((event) =>
            event.type == 'PUSH_HINT' && event.conversationId == 71),
      ),
    );

    realtime.signalPushRefresh(71);
    await received;

    await realtime.dispose();
  });

  test('invalid push conversation ids are ignored', () async {
    final realtime = MessagingRealtimeClient();
    final events = <Object>[];
    final subscription = realtime.events.listen(events.add);

    realtime.signalPushRefresh(null);
    realtime.signalPushRefresh(0);
    await Future<void>.delayed(Duration.zero);

    expect(events, isEmpty);
    await subscription.cancel();
    await realtime.dispose();
  });
}
