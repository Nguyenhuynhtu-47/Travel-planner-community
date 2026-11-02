import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/core/constants/map_constants.dart';
import 'package:mobile/core/constants/map_tile_provider_config.dart';
import 'package:mobile/shared/widgets/app_base_map.dart';

void main() {
  group('Phase 0 - Map Constants Verification', () {
    test(
        'MapConstants has neutral national geographic centroid fallback coordinates',
        () {
      // Confirms default coordinates point to the neutral national geographic centroid
      // of Vietnam (14.0583, 108.2772) rather than assuming any single fixed city (e.g. Da Nang 16.0544).
      expect(
          MapConstants.fallbackLatitude,
          equals(MapConstants.neutralCountryCentroidLatitude));
      expect(
          MapConstants.fallbackLongitude,
          equals(MapConstants.neutralCountryCentroidLongitude));
      expect(MapConstants.fallbackLatitude, equals(14.0583));
      expect(MapConstants.fallbackLongitude, equals(108.2772));
      expect(MapConstants.fallbackZoom, equals(6.0));
      expect(MapConstants.minZoom, equals(2.0));
      expect(MapConstants.maxZoom, equals(19.0));

      final coords = MapConstants.fallbackCoordinates;
      expect(coords.latitude, equals(14.0583));
      expect(coords.longitude, equals(108.2772));
    });

    test('MapConstants has valid tile endpoint and attribution defaults', () {
      expect(MapConstants.tileUrlTemplate, contains('{z}'));
      expect(MapConstants.tileUrlTemplate, contains('{x}'));
      expect(MapConstants.tileUrlTemplate, contains('{y}'));
      expect(MapConstants.tileUrlTemplate, contains('cartocdn.com'));
      expect(MapConstants.tileAttribution, contains('OpenStreetMap'));
      expect(MapConstants.tileAttribution, contains('CARTO'));
      expect(MapConstants.defaultSubdomains, equals(['a', 'b', 'c', 'd']));
      expect(
          MapConstants.userAgentPackageName, equals('com.travelplanner.mobile'));
    });
  });

  group('Phase 0 - Tile Provider Configuration Separation & Attribution Metadata', () {
    test('MapTileProviderConfig.defaultProvider loads from MapConstants with mandatory attribution', () {
      final config = MapTileProviderConfig.defaultProvider();
      expect(config.urlTemplate, equals(MapConstants.tileUrlTemplate));
      expect(config.attribution, equals(MapConstants.tileAttribution));
      expect(config.requiresAttribution, isTrue);
      expect(config.subdomains, equals(MapConstants.defaultSubdomains));
      expect(config.userAgentPackageName,
          equals(MapConstants.userAgentPackageName));
    });

    test(
        'MapTileProviderConfig allows switching providers without modifying map UI',
        () {
      final osmConfig = MapTileProviderConfig.openStreetMapDev();
      expect(osmConfig.urlTemplate, contains('tile.openstreetmap.org'));
      expect(osmConfig.attribution, equals('© OpenStreetMap contributors'));
      expect(osmConfig.requiresAttribution, isTrue);
      expect(osmConfig.subdomains, isEmpty);

      final cartoPositron = MapTileProviderConfig.carto(flavor: 'positron');
      expect(cartoPositron.urlTemplate, contains('positron'));
      expect(cartoPositron.requiresAttribution, isTrue);

      const customSelfHosted = MapTileProviderConfig(
        urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
        attribution: '',
        requiresAttribution: false,
        subdomains: ['x', 'y'],
      );
      expect(customSelfHosted.requiresAttribution, isFalse);
    });

    test('MapTileProviderConfig builds valid TileLayer and Attribution widgets',
        () {
      final config = MapTileProviderConfig.defaultProvider();
      final tileLayer = config.buildTileLayer();
      expect(tileLayer.urlTemplate, equals(MapConstants.tileUrlTemplate));
      expect(tileLayer.subdomains, equals(MapConstants.defaultSubdomains));

      final attributionWidget = config.buildAttributionWidget();
      expect(attributionWidget, isA<RichAttributionWidget>());

      const emptyConfig = MapTileProviderConfig(
        urlTemplate: 'https://example.com/{z}/{x}/{y}.png',
        attribution: '',
        requiresAttribution: false,
      );
      expect(emptyConfig.buildAttributionWidget(), isA<SizedBox>());
    });
  });

  group('Phase 0 - Camera Centering Priority Hierarchy', () {
    testWidgets(
        'Priority 3: AppBaseMap falls back to neutral national centroid when no coordinates provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(),
            ),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        flutterMap.options.initialCenter.latitude,
        equals(14.0583), // Vietnam national geographic centroid, not Da Nang (16.0544)
      );
      expect(
        flutterMap.options.initialCenter.longitude,
        equals(108.2772),
      );
      expect(
        flutterMap.options.initialZoom,
        equals(6.0),
      );
    });

    testWidgets(
        'Priority 1: AppBaseMap centers on caller-supplied coordinates (e.g. GPS or explicit location)',
        (WidgetTester tester) async {
      const explicitCoords = LatLng(10.8231, 106.6297); // Ho Chi Minh City
      const streetZoom = 14.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                initialCenter: explicitCoords,
                initialZoom: streetZoom,
              ),
            ),
          ),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.initialCenter.latitude, equals(10.8231));
      expect(flutterMap.options.initialCenter.longitude, equals(106.6297));
      expect(flutterMap.options.initialZoom, equals(14.0));
    });

    testWidgets(
        'Priority 2: AppBaseMap accepts initialCameraFit for contextual itinerary bounds framing',
        (WidgetTester tester) async {
      final bounds = LatLngBounds(
        const LatLng(10.0, 105.0),
        const LatLng(11.0, 106.0),
      );
      final cameraFit = CameraFit.bounds(bounds: bounds);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                initialCameraFit: cameraFit,
              ),
            ),
          ),
        ),
      );

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.initialCameraFit, equals(cameraFit));
    });
  });

  group('Phase 0 - Mandatory Map Attribution Safety', () {
    testWidgets(
        'Safe Design: showAttribution=false does NOT hide attribution when provider mandates it (CARTO/OSM)',
        (WidgetTester tester) async {
      // Verify that calling showAttribution = false during normal screen development
      // cannot accidentally hide legally required attribution on free providers.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                showAttribution: false, // Attempt to disable attribution
              ),
            ),
          ),
        ),
      );

      // Attribution MUST still be present because default CARTO requires attribution
      expect(find.byType(RichAttributionWidget), findsOneWidget);
    });

    testWidgets(
        'Safe Design: showAttribution=false works when provider does NOT mandate attribution',
        (WidgetTester tester) async {
      const privateConfig = MapTileProviderConfig(
        urlTemplate: 'https://private-tiles.example.com/{z}/{x}/{y}.png',
        attribution: '',
        requiresAttribution: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                tileProviderConfig: privateConfig,
                showAttribution: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RichAttributionWidget), findsNothing);
    });

    testWidgets(
        'Safe Design: customAttributionWidget replaces default badge when screen renders custom UI',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                customAttributionWidget: const Align(
                  alignment: Alignment.topLeft,
                  child: Text('Custom Legal Attribution Footer'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Legal Attribution Footer'), findsOneWidget);
      expect(find.byType(RichAttributionWidget), findsNothing);
    });

    testWidgets(
        'AttributionAlignment allows repositioning attribution badge to bottomLeft',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                attributionAlignment: AttributionAlignment.bottomLeft,
              ),
            ),
          ),
        ),
      );

      final widget =
          tester.widget<RichAttributionWidget>(find.byType(RichAttributionWidget));
      expect(widget.alignment, equals(AttributionAlignment.bottomLeft));
    });
  });

  group('Phase 0 - Non-Blocking Behavior & Extensibility', () {
    testWidgets('AppBaseMap renders additional children layers above tiles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                children: const [
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Text('Overlay Banner Test'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Overlay Banner Test'), findsOneWidget);
    });

    testWidgets(
        'AppBaseMap operates without location permission or GPS prompts',
        (WidgetTester tester) async {
      // Confirms map canvas renders without triggering any permission dialogs or platform channels
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(),
            ),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
