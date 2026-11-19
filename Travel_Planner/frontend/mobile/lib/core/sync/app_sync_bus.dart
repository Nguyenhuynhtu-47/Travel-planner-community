import 'dart:async';

/// Domains of data across the Travel Planner application.
enum SyncDomain {
  explore,
  itineraries,
  posts,
  comments,
  collections,
  profile,
  notifications,
  ratings,
}

/// Types of mutation / sync events that trigger data synchronization.
enum SyncEventType {
  created,
  updated,
  deleted,
  liked,
  unliked,
  saved,
  unsaved,
  favorited,
  unfavorited,
  reviewed,
  stale,
  refreshRequested,
}

/// Immutable event representing a change to domain data.
class SyncEvent {
  final SyncDomain domain;
  final SyncEventType type;
  final dynamic id;
  final dynamic payload;
  final DateTime timestamp;

  SyncEvent({
    required this.domain,
    required this.type,
    this.id,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'SyncEvent(domain: $domain, type: $type, id: $id, timestamp: $timestamp)';
}

/// Centralized event bus and cache invalidation coordinator.
///
/// Features:
/// 1. Broadcasts domain mutation events across tabs and screens.
/// 2. Tracks domain staleness with TTL and invalidation timestamps.
/// 3. Prevents redundant fetches and enables silent background updates.
/// 4. Ready for future WebSocket/STOMP push event dispatching.
class AppSyncBus {
  static final AppSyncBus instance = AppSyncBus._internal();

  factory AppSyncBus() => instance;

  AppSyncBus._internal();

  final StreamController<SyncEvent> _controller =
      StreamController<SyncEvent>.broadcast();

  final Map<SyncDomain, DateTime> _lastInvalidatedAt = {};
  final Map<SyncDomain, DateTime> _lastRefreshedAt = {};

  /// Default cache TTL per domain.
  final Map<SyncDomain, Duration> _defaultTtl = {
    SyncDomain.explore: const Duration(minutes: 5),
    SyncDomain.itineraries: const Duration(minutes: 3),
    SyncDomain.posts: const Duration(minutes: 3),
    SyncDomain.comments: const Duration(minutes: 2),
    SyncDomain.collections: const Duration(minutes: 3),
    SyncDomain.profile: const Duration(minutes: 5),
    SyncDomain.notifications: const Duration(minutes: 1),
    SyncDomain.ratings: const Duration(minutes: 3),
  };

  /// Stream of all sync events.
  Stream<SyncEvent> get events => _controller.stream;

  /// Stream filtered for a single domain.
  Stream<SyncEvent> on(SyncDomain domain) =>
      _controller.stream.where((e) => e.domain == domain);

  /// Stream filtered for any domain in [domains].
  Stream<SyncEvent> onAny(Set<SyncDomain> domains) =>
      _controller.stream.where((e) => domains.contains(e.domain));

  /// Configures custom TTL for a domain if needed.
  void setDomainTtl(SyncDomain domain, Duration ttl) {
    _defaultTtl[domain] = ttl;
  }

  /// Gets the configured TTL for a domain.
  Duration getDomainTtl(SyncDomain domain) {
    return _defaultTtl[domain] ?? const Duration(minutes: 3);
  }

  /// Broadcasts an event and marks the domain as invalidated.
  void emit(SyncEvent event) {
    _lastInvalidatedAt[event.domain] = event.timestamp;
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Explicitly marks a domain as stale (invalidated right now).
  void markStale(SyncDomain domain) {
    final now = DateTime.now();
    _lastInvalidatedAt[domain] = now;
    emit(SyncEvent(
      domain: domain,
      type: SyncEventType.stale,
      timestamp: now,
    ));
  }

  /// Records that a domain was freshly refreshed at [time] (or now).
  void recordRefreshed(SyncDomain domain, [DateTime? time]) {
    _lastRefreshedAt[domain] = time ?? DateTime.now();
    _lastInvalidatedAt.remove(domain);
  }

  /// Retrieves the last recorded refresh time for a domain.
  DateTime? getLastRefreshed(SyncDomain domain) {
    return _lastRefreshedAt[domain];
  }

  /// Checks if a domain is considered stale.
  ///
  /// A domain is stale if:
  /// - [lastRefreshed] is null (never refreshed).
  /// - An invalidation occurred for this domain after its last refresh.
  /// - Time since [lastRefreshed] exceeds [ttl] (or the default domain TTL).
  bool isStale(SyncDomain domain, {DateTime? lastRefreshed, Duration? ttl}) {
    final effectiveLastRefresh = lastRefreshed ?? _lastRefreshedAt[domain];
    if (effectiveLastRefresh == null) return true;

    final invalidation = _lastInvalidatedAt[domain];
    if (invalidation != null) {
      if (lastRefreshed == null || !invalidation.isBefore(effectiveLastRefresh)) {
        return true;
      }
    }

    final effectiveTtl = ttl ?? getDomainTtl(domain);
    return DateTime.now().difference(effectiveLastRefresh) > effectiveTtl;
  }

  // ==========================================
  // Static Helper Methods for Common Mutations
  // ==========================================

  /// Post was created. Invalidates posts and profile.
  static void emitPostCreated(dynamic post) {
    final event = SyncEvent(
      domain: SyncDomain.posts,
      type: SyncEventType.created,
      payload: post,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.profile);
  }

  /// Post was updated. Invalidates posts and profile.
  static void emitPostUpdated(dynamic post, [int? postId]) {
    final event = SyncEvent(
      domain: SyncDomain.posts,
      type: SyncEventType.updated,
      id: postId,
      payload: post,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.profile);
  }

  /// Post was deleted. Invalidates posts and profile.
  static void emitPostDeleted(int postId) {
    final event = SyncEvent(
      domain: SyncDomain.posts,
      type: SyncEventType.deleted,
      id: postId,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.profile);
  }

  /// Post was liked / unliked.
  static void emitPostLiked(int postId, bool isLiked, int likeCount) {
    instance.emit(SyncEvent(
      domain: SyncDomain.posts,
      type: isLiked ? SyncEventType.liked : SyncEventType.unliked,
      id: postId,
      payload: {'isLiked': isLiked, 'likeCount': likeCount},
    ));
  }

  /// Post comment count changed (comment or reply added/deleted).
  static void emitPostCommentChanged(int postId, int delta) {
    instance.emit(SyncEvent(
      domain: SyncDomain.posts,
      type: SyncEventType.updated,
      id: postId,
      payload: {'commentDelta': delta},
    ));
    instance.markStale(SyncDomain.comments);
  }

  /// Itinerary was created. Invalidates itineraries, collections, explore, profile.
  static void emitItineraryCreated(dynamic itinerary, [int? itineraryId]) {
    final event = SyncEvent(
      domain: SyncDomain.itineraries,
      type: SyncEventType.created,
      id: itineraryId,
      payload: itinerary,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.profile);
  }

  /// Itinerary was updated. Invalidates itineraries, collections, explore.
  static void emitItineraryUpdated(dynamic itinerary, [int? itineraryId]) {
    final event = SyncEvent(
      domain: SyncDomain.itineraries,
      type: SyncEventType.updated,
      id: itineraryId,
      payload: itinerary,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.collections);
    instance.markStale(SyncDomain.profile);
  }

  /// Itinerary was deleted. Invalidates itineraries, collections, explore, profile.
  static void emitItineraryDeleted(int itineraryId) {
    final event = SyncEvent(
      domain: SyncDomain.itineraries,
      type: SyncEventType.deleted,
      id: itineraryId,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.collections);
    instance.markStale(SyncDomain.profile);
  }

  /// Itinerary saved / unsaved. Updates collections and explore.
  static void emitItinerarySaved(int itineraryId, bool isSaved) {
    final event = SyncEvent(
      domain: SyncDomain.collections,
      type: isSaved ? SyncEventType.saved : SyncEventType.unsaved,
      id: itineraryId,
      payload: {'isSaved': isSaved},
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.itineraries);
  }

  /// Itinerary favorited / unfavorited. Updates collections and explore.
  static void emitItineraryFavorited(int itineraryId, bool isFavorited) {
    final event = SyncEvent(
      domain: SyncDomain.collections,
      type: isFavorited ? SyncEventType.favorited : SyncEventType.unfavorited,
      id: itineraryId,
      payload: {'isFavorited': isFavorited},
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.itineraries);
  }

  /// Itinerary rating submitted or updated. Updates explore and itineraries.
  static void emitItineraryRatingChanged(
      int itineraryId, double rating, int count) {
    final event = SyncEvent(
      domain: SyncDomain.ratings,
      type: SyncEventType.reviewed,
      id: itineraryId,
      payload: {'rating': rating, 'count': count},
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.itineraries);
  }

  /// User profile or avatar was updated.
  static void emitProfileUpdated(dynamic profile) {
    final event = SyncEvent(
      domain: SyncDomain.profile,
      type: SyncEventType.updated,
      payload: profile,
    );
    instance.emit(event);
    instance.markStale(SyncDomain.explore);
    instance.markStale(SyncDomain.posts);
  }

  /// Request a manual or automatic refresh of a domain.
  static void requestRefresh(SyncDomain domain) {
    instance.emit(SyncEvent(
      domain: domain,
      type: SyncEventType.refreshRequested,
    ));
  }

  /// Dispatches remote messages received via WebSocket/STOMP without
  /// architectural redesign.
  void handleRemoteSyncMessage(Map<String, dynamic> data) {
    final domainName = data['domain']?.toString();
    final action = data['action']?.toString();
    final id = data['id'];
    final payload = data['payload'];

    SyncDomain? domain;
    for (final d in SyncDomain.values) {
      if (d.name == domainName) {
        domain = d;
        break;
      }
    }
    if (domain == null) return;

    SyncEventType type = SyncEventType.updated;
    if (action == 'CREATE' || action == 'created') {
      type = SyncEventType.created;
    } else if (action == 'DELETE' || action == 'deleted') {
      type = SyncEventType.deleted;
    }

    emit(SyncEvent(
      domain: domain,
      type: type,
      id: id,
      payload: payload,
    ));
  }

  /// Resets all sync state (useful during logout or test teardown).
  void reset() {
    _lastInvalidatedAt.clear();
    _lastRefreshedAt.clear();
  }
}
