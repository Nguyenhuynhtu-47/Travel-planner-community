import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/shared/widgets/app_map_view.dart';

void main() {
  group('Phase 3 - AppMapView Widget Rendering & Camera Configuration', () {
    testWidgets('AppMapView renders FlutterMap with neutral country centroid fallback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(),
            ),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.initialCenter.latitude,
          equals(MapConstants.neutralCountryCentroidLatitude));
      expect(flutterMap.options.initialCenter.longitude,
          equals(MapConstants.neutralCountryCentroidLongitude));
      expect(flutterMap.options.initialZoom, equals(MapConstants.fallbackZoom));
    });

    testWidgets('AppMapView accepts custom initialCenter and initialZoom',
        (WidgetTester tester) async {
      const hanoi = LatLng(21.0285, 105.8544);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                initialCenter: hanoi,
                initialZoom: 15.0,
              ),
            ),
          ),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.initialCenter, equals(hanoi));
      expect(flutterMap.options.initialZoom, equals(15.0));
    });

    testWidgets('AppMapView accepts initialCameraFit for contextual framing',
        (WidgetTester tester) async {
      final bounds = LatLngBounds(
        const LatLng(11.90, 108.40),
        const LatLng(11.98, 108.48),
      );
      final cameraFit = CameraFit.bounds(bounds: bounds);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                initialCameraFit: cameraFit,
              ),
            ),
          ),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.initialCameraFit, equals(cameraFit));
    });

    testWidgets('AppMapView respects configurable interactionOptions',
        (WidgetTester tester) async {
      const customInteractions = InteractionOptions(
        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                interactionOptions: customInteractions,
              ),
            ),
          ),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.interactionOptions.flags,
          equals(InteractiveFlag.pinchZoom | InteractiveFlag.drag));
    });
  });

  group('Phase 3 - AppMapView Layer Composition & Overlays', () {
    testWidgets('AppMapView renders MarkerLayer when markers are provided',
        (WidgetTester tester) async {
      final markers = [
        MapMarkerBuilder.buildStopMarker(
          point: const LatLng(11.9404, 108.4378),
          sequence: 1,
          dayBadge: 'D1',
        ),
        MapMarkerBuilder.buildPinMarker(
          point: const LatLng(11.9421, 108.4362),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                markers: markers,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('D1'), findsOneWidget);
      expect(find.byIcon(Icons.place), findsOneWidget);
    });

    testWidgets('AppMapView renders PolylineLayer when polylines are provided',
        (WidgetTester tester) async {
      final polylines = [
        Polyline<Object>(
          points: const [
            LatLng(11.9404, 108.4378),
            LatLng(11.9421, 108.4362),
          ],
          color: AppColors.primary,
          strokeWidth: 4.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                polylines: polylines,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PolylineLayer<Object>), findsOneWidget);
    });

    testWidgets('AppMapView composes layers in correct order (Tile -> Polyline -> Marker -> Children)',
        (WidgetTester tester) async {
      final polylines = [
        Polyline<Object>(
          points: const [LatLng(10.0, 106.0), LatLng(10.1, 106.1)],
          color: Colors.blue,
        ),
      ];
      final markers = [
        MapMarkerBuilder.buildGpsMarker(point: const LatLng(10.0, 106.0)),
      ];
      const customLayer = CircleAvatar(key: Key('custom_overlay_widget'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                polylines: polylines,
                markers: markers,
                children: const [customLayer],
              ),
            ),
          ),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final layers = flutterMap.children;

      // Layer 0: TileLayer
      expect(layers[0], isA<TileLayer>());
      // Layer 1: PolylineLayer
      expect(layers[1], isA<PolylineLayer<Object>>());
      // Layer 2: MarkerLayer
      expect(layers[2], isA<MarkerLayer>());
      // Layer 3: Custom child layer
      expect(layers[3], isA<CircleAvatar>());
      // Layer 4: Attribution layer
      expect(layers[4], isA<RichAttributionWidget>());
    });
  });

  group('Phase 3 - Mandatory Attribution Compliance', () {
    testWidgets('RichAttributionWidget is present and cannot be accidentally hidden on CARTO',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                showAttribution: false, // Attempt to hide
              ),
            ),
          ),
        ),
      );

      // Attribution must still be rendered because CARTO mandates attribution
      expect(find.byType(RichAttributionWidget), findsOneWidget);
    });

    testWidgets('Attribution alignment can be configured to bottomLeft to avoid FAB overlap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                attributionAlignment: AttributionAlignment.bottomLeft,
              ),
            ),
          ),
        ),
      );

      final attribution =
          tester.widget<RichAttributionWidget>(find.byType(RichAttributionWidget));
      expect(attribution.alignment, equals(AttributionAlignment.bottomLeft));
    });

    testWidgets('Custom attribution widget replaces default when supplied',
        (WidgetTester tester) async {
      const customWidget = Text('Custom Attribution Notice', key: Key('custom_attr'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                customAttributionWidget: customWidget,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom_attr')), findsOneWidget);
      expect(find.byType(RichAttributionWidget), findsNothing);
    });
  });

  group('Phase 3 - MapMarkerBuilder Unit & Widget Tests', () {
    testWidgets('buildStopMarker builds marker with correct dimensions and alignment',
        (WidgetTester tester) async {
      const point = LatLng(10.7721, 106.6983);
      var tapped = false;

      final marker = MapMarkerBuilder.buildStopMarker(
        point: point,
        sequence: 3,
        dayBadge: 'Ngày 2',
        width: 44.0,
        height: 56.0,
        onTap: () => tapped = true,
      );

      expect(marker.point, equals(point));
      expect(marker.width, equals(44.0));
      expect(marker.height, equals(56.0));
      expect(marker.alignment, equals(Alignment.topCenter));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Ngày 2'), findsOneWidget);

      await tester.tap(find.text('3'));
      expect(tapped, isTrue);
    });

    testWidgets('buildStopMarker with icon renders icon when sequence is omitted',
        (WidgetTester tester) async {
      final marker = MapMarkerBuilder.buildStopMarker(
        point: const LatLng(10.0, 106.0),
        icon: Icons.restaurant,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('buildPinMarker creates pin with Alignment.topCenter',
        (WidgetTester tester) async {
      const point = LatLng(16.0544, 108.2022);
      var tapped = false;

      final marker = MapMarkerBuilder.buildPinMarker(
        point: point,
        color: AppColors.primary,
        onTap: () => tapped = true,
      );

      expect(marker.point, equals(point));
      expect(marker.alignment, equals(Alignment.topCenter));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.place), findsOneWidget);
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('buildGpsMarker creates centered circular marker with Alignment.center',
        (WidgetTester tester) async {
      const point = LatLng(21.0285, 105.8544);
      final marker = MapMarkerBuilder.buildGpsMarker(
        point: point,
        size: 24.0,
      );

      expect(marker.point, equals(point));
      expect(marker.width, equals(24.0));
      expect(marker.height, equals(24.0));
      expect(marker.alignment, equals(Alignment.center));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Vị trí hiện tại của bạn'), findsOneWidget);
    });

    testWidgets('buildNumberedMarker creates centered badge with number',
        (WidgetTester tester) async {
      const point = LatLng(12.2388, 109.1967);
      var tapped = false;

      final marker = MapMarkerBuilder.buildNumberedMarker(
        point: point,
        number: 7,
        size: 30.0,
        onTap: () => tapped = true,
      );

      expect(marker.point, equals(point));
      expect(marker.alignment, equals(Alignment.center));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
            ),
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      await tester.tap(find.text('7'));
      expect(tapped, isTrue);
    });

    testWidgets('buildCustomMarker renders arbitrary widget cleanly',
        (WidgetTester tester) async {
      const point = LatLng(10.0, 105.0);
      var tapped = false;

      final marker = MapMarkerBuilder.buildCustomMarker(
        point: point,
        child: const Text('CUSTOM'),
        onTap: () => tapped = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marker.width,
                height: marker.height,
                child: marker.child,
              ),
            ),
          ),
        ),
      );

      expect(find.text('CUSTOM'), findsOneWidget);
      await tester.tap(find.text('CUSTOM'));
      expect(tapped, isTrue);
    });
  });

  group('Phase 3 - Lifecycle, Memory Safety & Layout Constraints', () {
    testWidgets('AppMapView renders without layout overflow on compact mobile screen (320x480)',
        (WidgetTester tester) async {
      final markers = [
        MapMarkerBuilder.buildStopMarker(
          point: const LatLng(14.0583, 108.2772),
          sequence: 1,
          dayBadge: 'Day 1',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 480,
              child: AppMapView(
                markers: markers,
              ),
            ),
          ),
        ),
      );

      // Verify no Flutter error or layout overflow
      expect(tester.takeException(), isNull);
      expect(find.byType(AppMapView), findsOneWidget);
    });

    testWidgets('AppMapView widget lifecycle: mount, rebuild with new markers, and unmount cleanly',
        (WidgetTester tester) async {
      final controller = MapController();

      // 1. Initial Mount
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                mapController: controller,
                markers: [
                  MapMarkerBuilder.buildStopMarker(
                    point: const LatLng(10.0, 105.0),
                    sequence: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);

      // 2. Rebuild with updated markers
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 375,
              height: 600,
              child: AppMapView(
                mapController: controller,
                markers: [
                  MapMarkerBuilder.buildStopMarker(
                    point: const LatLng(10.0, 105.0),
                    sequence: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      // 3. Unmount cleanly
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
      expect(find.byType(AppMapView), findsNothing);
      expect(tester.takeException(), isNull);

      // Dispose controller safely
      controller.dispose();
    });
  });
}
