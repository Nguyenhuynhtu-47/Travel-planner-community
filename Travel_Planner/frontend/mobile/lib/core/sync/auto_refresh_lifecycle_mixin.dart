import 'dart:async';
import 'package:flutter/material.dart';

import 'app_sync_bus.dart';

class _SyncLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResumed;

  _SyncLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

/// Mixin for [State] widgets that need automatic data synchronization
/// and lifecycle-aware auto-refreshing.
///
/// Handles:
/// 1. Subscription to [AppSyncBus] events matching [syncDomains].
/// 2. Background refresh when returning to foreground ([AppLifecycleState.resumed]).
/// 3. Debouncing rapid tab switches or repeated triggers via [minRefreshInterval].
/// 4. Preserves scroll position and prevents full-screen layout flashing by
///    requesting [onRefreshData] with `isBackground: true`.
/// 5. Gracefully handles unmounting and outdated responses.
mixin AutoRefreshLifecycleMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<SyncEvent>? _syncSubscription;
  _SyncLifecycleObserver? _lifecycleObserver;
  DateTime? _lastRefreshed;
  bool _isRefreshing = false;

  /// The data domains this screen depends on.
  Set<SyncDomain> get syncDomains;

  /// Max age before data is considered stale for this screen.
  Duration get syncTtl => const Duration(minutes: 3);

  /// Minimum interval between background network syncs to prevent rapid spamming.
  Duration get minRefreshInterval => const Duration(seconds: 4);

  /// Whether to automatically check and refresh when the app returns to the foreground.
  bool get autoRefreshOnResume => true;

  /// Last successful refresh time recorded by this mixin.
  DateTime? get lastRefreshed => _lastRefreshed;

  /// Whether a sync refresh is currently executing.
  bool get isSyncRefreshing => _isRefreshing;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _SyncLifecycleObserver(onResumed: _handleAppResumed);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    _setupSyncSubscription();
  }

  void _setupSyncSubscription() {
    if (syncDomains.isEmpty) return;
    _syncSubscription = AppSyncBus.instance.onAny(syncDomains).listen((event) {
      if (!mounted) return;
      onSyncEvent(event);
    });
  }

  @override
  void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _handleAppResumed() {
    if (!mounted) return;
    onAppResumed();
    if (autoRefreshOnResume) {
      refreshIfStale(isBackground: true);
    }
  }

  /// Hook called when the application transitions to resumed (foreground).
  @protected
  void onAppResumed() {}

  /// Called when an [AppSyncBus] event arrives for one of [syncDomains].
  /// Default implementation triggers a background refresh if stale.
  @protected
  void onSyncEvent(SyncEvent event) {
    if (!mounted) return;
    refreshIfStale(isBackground: true);
  }

  /// Triggers [onRefreshData] if any domain in [syncDomains] is stale,
  /// respecting [minRefreshInterval] unless [force] is true.
  Future<void> refreshIfStale({
    bool isBackground = true,
    bool force = false,
  }) async {
    if (!mounted || _isRefreshing) return;

    final now = DateTime.now();
    if (!force && _lastRefreshed != null) {
      if (now.difference(_lastRefreshed!) < minRefreshInterval) {
        return; // Throttled
      }
    }

    final hasStaleDomain = force ||
        syncDomains.isEmpty ||
        syncDomains.any((domain) => AppSyncBus.instance.isStale(
              domain,
              lastRefreshed: _lastRefreshed,
              ttl: syncTtl,
            ));

    if (!hasStaleDomain) return;

    _isRefreshing = true;
    try {
      await onRefreshData(isBackground: isBackground);
      if (mounted) {
        _lastRefreshed = DateTime.now();
        for (final domain in syncDomains) {
          AppSyncBus.instance.recordRefreshed(domain, _lastRefreshed);
        }
      }
    } catch (_) {
      // Background auto-refresh swallows error to prevent disrupting UI;
      // manual pull-to-refresh will surface UI errors directly.
    } finally {
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  /// Explicitly records that data was refreshed (e.g. from pull-to-refresh).
  void recordRefreshedNow([DateTime? time]) {
    _lastRefreshed = time ?? DateTime.now();
    for (final domain in syncDomains) {
      AppSyncBus.instance.recordRefreshed(domain, _lastRefreshed);
    }
  }

  /// Core data fetching method implemented by each screen.
  /// When [isBackground] is true, avoid showing full-screen spinners.
  @protected
  Future<void> onRefreshData({bool isBackground = false});
}
