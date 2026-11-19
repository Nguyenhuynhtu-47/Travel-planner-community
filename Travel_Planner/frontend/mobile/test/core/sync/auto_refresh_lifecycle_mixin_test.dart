import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sync/app_sync_bus.dart';
import 'package:mobile/core/sync/auto_refresh_lifecycle_mixin.dart';

class TestAutoRefreshWidget extends StatefulWidget {
  final VoidCallback onRefreshCalled;
  final Duration throttleInterval;
  final Set<SyncDomain> domains;

  const TestAutoRefreshWidget({
    super.key,
    required this.onRefreshCalled,
    this.throttleInterval = const Duration(seconds: 4),
    this.domains = const {SyncDomain.posts},
  });

  @override
  TestAutoRefreshWidgetState createState() => TestAutoRefreshWidgetState();
}

class TestAutoRefreshWidgetState extends State<TestAutoRefreshWidget>
    with AutoRefreshLifecycleMixin<TestAutoRefreshWidget> {
  int refreshCallCount = 0;

  @override
  Set<SyncDomain> get syncDomains => widget.domains;

  @override
  Duration get minRefreshInterval => widget.throttleInterval;

  @override
  Future<void> onRefreshData({bool isBackground = false}) async {
    setState(() {
      refreshCallCount++;
    });
    widget.onRefreshCalled();
  }

  @override
  Widget build(BuildContext context) {
    return Text('Refresh count: $refreshCallCount');
  }
}

void main() {
  group('AutoRefreshLifecycleMixin Widget Tests', () {
    late AppSyncBus bus;

    setUp(() {
      bus = AppSyncBus.instance;
      bus.reset();
    });

    testWidgets('triggers onRefreshData when domain is stale', (tester) async {
      int refreshedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TestAutoRefreshWidget(
            onRefreshCalled: () => refreshedCount++,
          ),
        ),
      );

      final state =
          tester.state<TestAutoRefreshWidgetState>(find.byType(TestAutoRefreshWidget));

      // Domain starts stale
      await state.refreshIfStale(isBackground: true);
      await tester.pump();

      expect(refreshedCount, 1);
      expect(find.text('Refresh count: 1'), findsOneWidget);
    });

    testWidgets('throttles refresh calls within minRefreshInterval', (tester) async {
      int refreshedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TestAutoRefreshWidget(
            onRefreshCalled: () => refreshedCount++,
            throttleInterval: const Duration(seconds: 5),
          ),
        ),
      );

      final state =
          tester.state<TestAutoRefreshWidgetState>(find.byType(TestAutoRefreshWidget));

      // First call succeeds
      await state.refreshIfStale(isBackground: true);
      expect(refreshedCount, 1);

      // Invalidate domain again
      bus.markStale(SyncDomain.posts);

      // Second call immediately within throttle interval should be skipped
      await state.refreshIfStale(isBackground: true);
      expect(refreshedCount, 1);

      // Force refresh bypasses throttle
      await state.refreshIfStale(isBackground: true, force: true);
      expect(refreshedCount, 2);
    });

    testWidgets('responds to AppSyncBus events and refreshes stale domain',
        (tester) async {
      int refreshedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TestAutoRefreshWidget(
            onRefreshCalled: () => refreshedCount++,
            throttleInterval: Duration.zero,
          ),
        ),
      );

      final state =
          tester.state<TestAutoRefreshWidgetState>(find.byType(TestAutoRefreshWidget));
      await state.refreshIfStale(isBackground: true);
      expect(refreshedCount, 1);

      // Emit post event
      AppSyncBus.emitPostCreated({'postId': 123});
      await tester.pump(const Duration(milliseconds: 50));

      expect(refreshedCount, 2);
    });

    testWidgets('handles app resumed lifecycle state by triggering background refresh',
        (tester) async {
      int refreshedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TestAutoRefreshWidget(
            onRefreshCalled: () => refreshedCount++,
            throttleInterval: Duration.zero,
          ),
        ),
      );

      final state =
          tester.state<TestAutoRefreshWidgetState>(find.byType(TestAutoRefreshWidget));
      await state.refreshIfStale(isBackground: true);
      expect(refreshedCount, 1);

      // Mark domain stale while in background
      bus.markStale(SyncDomain.posts);

      // App transitions to resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));

      expect(refreshedCount, 2);
    });
  });
}
