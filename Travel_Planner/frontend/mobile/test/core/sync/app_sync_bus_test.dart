import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/app_sync_bus.dart';

void main() {
  group('AppSyncBus Core Tests', () {
    late AppSyncBus bus;

    setUp(() {
      bus = AppSyncBus.instance;
      bus.reset();
    });

    test('is singleton', () {
      expect(identical(AppSyncBus.instance, AppSyncBus()), isTrue);
    });

    test('isStale returns true when domain has never refreshed', () {
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
    });

    test('isStale returns false immediately after recording refresh', () {
      bus.recordRefreshed(SyncDomain.explore);
      expect(bus.isStale(SyncDomain.explore), isFalse);
    });

    test('isStale returns true when domain TTL is exceeded', () {
      final past = DateTime.now().subtract(const Duration(minutes: 10));
      bus.recordRefreshed(SyncDomain.itineraries, past);
      expect(
        bus.isStale(
          SyncDomain.itineraries,
          lastRefreshed: past,
          ttl: const Duration(minutes: 3),
        ),
        isTrue,
      );
    });

    test('markStale invalidates domain even if refreshed recently', () {
      bus.recordRefreshed(SyncDomain.posts);
      expect(bus.isStale(SyncDomain.posts), isFalse);

      bus.markStale(SyncDomain.posts);
      expect(bus.isStale(SyncDomain.posts), isTrue);
    });

    test('emit broadcasts SyncEvent on stream and filters by domain', () async {
      final receivedEvents = <SyncEvent>[];
      final subscription = bus.on(SyncDomain.posts).listen(receivedEvents.add);

      bus.emit(SyncEvent(
        domain: SyncDomain.posts,
        type: SyncEventType.created,
        id: 101,
      ));

      bus.emit(SyncEvent(
        domain: SyncDomain.itineraries,
        type: SyncEventType.created,
        id: 202,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(receivedEvents.length, 1);
      expect(receivedEvents.first.domain, SyncDomain.posts);
      expect(receivedEvents.first.id, 101);

      await subscription.cancel();
    });

    test('onAny receives events for all subscribed domains', () async {
      final received = <SyncDomain>[];
      final subscription = bus
          .onAny({SyncDomain.explore, SyncDomain.collections})
          .listen((e) => received.add(e.domain));

      bus.emit(SyncEvent(domain: SyncDomain.explore, type: SyncEventType.stale));
      bus.emit(SyncEvent(domain: SyncDomain.posts, type: SyncEventType.stale));
      bus.emit(SyncEvent(domain: SyncDomain.collections, type: SyncEventType.stale));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received, [SyncDomain.explore, SyncDomain.collections]);

      await subscription.cancel();
    });

    test('emitPostCreated marks profile and posts stale', () {
      bus.recordRefreshed(SyncDomain.posts);
      bus.recordRefreshed(SyncDomain.profile);
      expect(bus.isStale(SyncDomain.posts), isFalse);
      expect(bus.isStale(SyncDomain.profile), isFalse);

      AppSyncBus.emitPostCreated({'id': 1});
      expect(bus.isStale(SyncDomain.posts), isTrue);
      expect(bus.isStale(SyncDomain.profile), isTrue);
    });

    test('emitItineraryCreated marks itineraries, explore, profile stale', () {
      bus.recordRefreshed(SyncDomain.itineraries);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.profile);

      AppSyncBus.emitItineraryCreated({'id': 1}, 1);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.profile), isTrue);
    });

    test('emitItinerarySaved marks collections, explore, itineraries stale', () {
      bus.recordRefreshed(SyncDomain.collections);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.itineraries);

      AppSyncBus.emitItinerarySaved(42, true);
      expect(bus.isStale(SyncDomain.collections), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
    });

    test('emitItineraryRatingChanged marks ratings, explore, itineraries stale', () {
      bus.recordRefreshed(SyncDomain.ratings);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.itineraries);

      AppSyncBus.emitItineraryRatingChanged(55, 4.8, 12);
      expect(bus.isStale(SyncDomain.ratings), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
    });

    test('handleRemoteSyncMessage parses WebSocket/STOMP payload correctly', () async {
      SyncEvent? eventReceived;
      final sub = bus.events.listen((e) => eventReceived = e);

      bus.handleRemoteSyncMessage({
        'domain': 'posts',
        'action': 'CREATE',
        'id': 999,
        'payload': {'content': 'Remote post from WebSocket'},
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(eventReceived, isNotNull);
      expect(eventReceived!.domain, SyncDomain.posts);
      expect(eventReceived!.type, SyncEventType.created);
      expect(eventReceived!.id, 999);

      await sub.cancel();
    });
  });
}
