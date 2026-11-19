import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/app_sync_bus.dart';
import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/presentation/community_feed_notifier.dart';

void main() {
  group('Global Auto Refresh & Data Synchronization Integration Tests', () {
    late AppSyncBus bus;

    setUp(() {
      bus = AppSyncBus.instance;
      bus.reset();
    });

    test('Liking a post in CommunityFeedNotifier broadcasts SyncEventType.liked event',
        () async {
      final notifier = CommunityFeedNotifier();
      final post = PostModel(
        postId: 456,
        author: const PostAuthorModel(userId: 1, fullName: 'Test User', handle: 'test'),
        content: 'Post content',
        mediaUrls: const [],
        mediaAssetIds: const [],
        createdAt: DateTime.now(),
        visibility: 'PUBLIC',
        likeCount: 0,
        isLikedByMe: false,
      );
      notifier.addPost(post);

      SyncEvent? capturedEvent;
      final sub = bus.on(SyncDomain.posts).listen((e) => capturedEvent = e);

      notifier.applyLikeUpdate(456, true, 1);

      expect(notifier.publicPosts.first.isLikedByMe, isTrue);
      expect(notifier.publicPosts.first.likeCount, 1);

      AppSyncBus.emitPostLiked(456, true, 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.type, SyncEventType.liked);
      expect(capturedEvent!.id, 456);
      expect((capturedEvent!.payload as Map)['isLiked'], isTrue);

      await sub.cancel();
      notifier.dispose();
    });

    test('Creating an itinerary emits SyncEventType.created and marks explore and collections stale',
        () {
      bus.recordRefreshed(SyncDomain.itineraries);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.collections);

      expect(bus.isStale(SyncDomain.itineraries), isFalse);
      expect(bus.isStale(SyncDomain.explore), isFalse);
      expect(bus.isStale(SyncDomain.collections), isFalse);

      AppSyncBus.emitItineraryCreated({'itineraryId': 99, 'title': 'Trip to Da Lat'}, 99);

      expect(bus.isStale(SyncDomain.itineraries), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.profile), isTrue);
    });

    test('Updating an itinerary emits SyncEventType.updated and marks explore, collections, profile stale',
        () {
      bus.recordRefreshed(SyncDomain.itineraries);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.collections);
      bus.recordRefreshed(SyncDomain.profile);

      AppSyncBus.emitItineraryUpdated({'itineraryId': 99, 'title': 'Updated Title'}, 99);

      expect(bus.isStale(SyncDomain.itineraries), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.collections), isTrue);
      expect(bus.isStale(SyncDomain.profile), isTrue);
    });

    test('Deleting an itinerary emits SyncEventType.deleted and invalidates domains',
        () {
      bus.recordRefreshed(SyncDomain.itineraries);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.collections);

      AppSyncBus.emitItineraryDeleted(99);

      expect(bus.isStale(SyncDomain.itineraries), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.collections), isTrue);
      expect(bus.isStale(SyncDomain.profile), isTrue);
    });

    test('Saving an itinerary emits SyncEventType.saved and invalidates collections and explore',
        () {
      bus.recordRefreshed(SyncDomain.collections);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.itineraries);

      AppSyncBus.emitItinerarySaved(10, true);

      expect(bus.isStale(SyncDomain.collections), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
    });

    test('Favoriting an itinerary emits SyncEventType.favorited and invalidates collections and explore',
        () {
      bus.recordRefreshed(SyncDomain.collections);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.itineraries);

      AppSyncBus.emitItineraryFavorited(10, true);

      expect(bus.isStale(SyncDomain.collections), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
    });

    test('Submitting itinerary rating emits SyncEventType.reviewed and invalidates ratings and explore',
        () {
      bus.recordRefreshed(SyncDomain.ratings);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.itineraries);

      AppSyncBus.emitItineraryRatingChanged(10, 4.5, 8);

      expect(bus.isStale(SyncDomain.ratings), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.itineraries), isTrue);
    });

    test('Updating profile emits SyncEventType.updated and marks profile, explore, posts stale',
        () {
      bus.recordRefreshed(SyncDomain.profile);
      bus.recordRefreshed(SyncDomain.explore);
      bus.recordRefreshed(SyncDomain.posts);

      AppSyncBus.emitProfileUpdated({'fullName': 'New Name'});

      expect(bus.isStale(SyncDomain.profile), isTrue);
      expect(bus.isStale(SyncDomain.explore), isTrue);
      expect(bus.isStale(SyncDomain.posts), isTrue);
    });

    test('Tab switch refresh request triggers domain event', () async {
      final emitted = <SyncDomain>[];
      final sub = bus.events.listen((e) {
        if (e.type == SyncEventType.refreshRequested) {
          emitted.add(e.domain);
        }
      });

      AppSyncBus.requestRefresh(SyncDomain.explore);
      AppSyncBus.requestRefresh(SyncDomain.posts);
      AppSyncBus.requestRefresh(SyncDomain.collections);
      AppSyncBus.requestRefresh(SyncDomain.itineraries);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emitted, [
        SyncDomain.explore,
        SyncDomain.posts,
        SyncDomain.collections,
        SyncDomain.itineraries,
      ]);

      await sub.cancel();
    });
  });
}
