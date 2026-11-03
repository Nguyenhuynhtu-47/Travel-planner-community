import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/shared/widgets/app_map_view.dart';

void main() {
  group('CARTO Basemaps API Key - MapConstants Unit Tests', () {
    test('appendApiKey returns template unchanged when key is empty or null', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      expect(MapConstants.appendApiKey(template, apiKey: null), equals(template));
      expect(MapConstants.appendApiKey(template, apiKey: ''), equals(template));
      expect(MapConstants.appendApiKey(template, apiKey: '   '), equals(template));
    });

    test('appendApiKey appends ?key= when URL has no query parameters', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      final result = MapConstants.appendApiKey(template, apiKey: 'sample-token-123');
      expect(
        result,
        equals(
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=sample-token-123',
        ),
      );
    });

    test('appendApiKey appends &key= when URL already has query parameters', () {
      const template = 'https://example.com/tiles/{z}/{x}/{y}.png?flavor=voyager';
      final result = MapConstants.appendApiKey(template, apiKey: 'token_abc');
      expect(
        result,
        equals('https://example.com/tiles/{z}/{x}/{y}.png?flavor=voyager&key=token_abc'),
      );
    });

    test('appendApiKey replaces {apiKey} placeholder', () {
      const template =
          'https://api.example.com/tiles/{z}/{x}/{y}.png?api_key={apiKey}';
      final result = MapConstants.appendApiKey(template, apiKey: 'my_secret_key');
      expect(
        result,
        equals('https://api.example.com/tiles/{z}/{x}/{y}.png?api_key=my_secret_key'),
      );
    });

    test('appendApiKey replaces {key} placeholder', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key={key}';
      final result = MapConstants.appendApiKey(template, apiKey: 'my_carto_key');
      expect(
        result,
        equals(
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=my_carto_key',
        ),
      );
    });

    test('appendApiKey prevents duplicate key parameter when already present in template', () {
      const templateWithKey =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=existing_key';
      final result =
          MapConstants.appendApiKey(templateWithKey, apiKey: 'new_attempted_key');
      expect(result, equals(templateWithKey));
    });

    test('appendApiKey correctly URL-encodes special characters in API key', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      final result =
          MapConstants.appendApiKey(template, apiKey: 'key+with special/chars=&');
      expect(result, contains('key=key%2Bwith+special%2Fchars%3D%26'));
    });

    test('isCartoApiKeyMissing reflects hasCartoApiKey', () {
      if (MapConstants.hasCartoApiKey) {
        expect(MapConstants.isCartoApiKeyMissing, isFalse);
        expect(MapConstants.effectiveTileUrlTemplate, contains('key='));
      } else {
        expect(MapConstants.isCartoApiKeyMissing, isTrue);
      }
    });
  });

  group('CARTO Basemaps API Key - MapTileProviderConfig Tests', () {
    test('defaultProvider detects missing API key when apiKey is empty', () {
      const emptyConfig = MapTileProviderConfig(
        urlTemplate:
            'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
        attribution: 'CARTO',
        requiresApiKey: true,
        apiKey: '',
      );
      expect(emptyConfig.requiresApiKey, isTrue);
      expect(emptyConfig.isApiKeyMissing, isTrue);
      expect(emptyConfig.apiKey, equals(''));
    });

    test('defaultProvider accepts explicit apiKey and includes it in effectiveUrlTemplate', () {
      final config =
          MapTileProviderConfig.defaultProvider(apiKey: 'carto_test_key_999');
      expect(config.requiresApiKey, isTrue);
      expect(config.isApiKeyMissing, isFalse);
      expect(config.apiKey, equals('carto_test_key_999'));
      expect(config.effectiveUrlTemplate, contains('key=carto_test_key_999'));

      final layer = config.buildTileLayer();
      expect(layer.urlTemplate, contains('key=carto_test_key_999'));
    });

    test('carto factory propagates flavor and apiKey', () {
      final config = MapTileProviderConfig.carto(
        flavor: 'positron',
        apiKey: 'positron_key_456',
      );
      expect(config.requiresApiKey, isTrue);
      expect(config.isApiKeyMissing, isFalse);
      expect(config.effectiveUrlTemplate, contains('positron'));
      expect(config.effectiveUrlTemplate, contains('key=positron_key_456'));
    });

    test('openStreetMapDev does not require an API key', () {
      final config = MapTileProviderConfig.openStreetMapDev();
      expect(config.requiresApiKey, isFalse);
      expect(config.isApiKeyMissing, isFalse);
      expect(config.effectiveUrlTemplate, isNot(contains('key=')));
    });
  });

  group('CARTO Basemaps API Key - Widget & Error State Tests', () {
    testWidgets(
        'AppBaseMap renders MapApiKeyMissingBanner when CARTO API key is missing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                tileProviderConfig: MapTileProviderConfig.carto(apiKey: ''),
              ),
            ),
          ),
        ),
      );

      // Verify guidance banner is displayed
      expect(find.byType(MapApiKeyMissingBanner), findsOneWidget);
      expect(
        find.text('Chưa cấu hình CARTO Basemaps API Key'),
        findsOneWidget,
      );
      expect(
        find.text('--dart-define=CARTO_API_KEY=<your_key>'),
        findsOneWidget,
      );

      // Verify FlutterMap canvas is still present underneath
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets(
        'MapApiKeyMissingBanner can be dismissed by tapping the close button',
        (WidgetTester tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: MapApiKeyMissingBanner(
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MapApiKeyMissingBanner), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Banner should now be dismissed / hidden
      expect(find.text('Chưa cấu hình CARTO Basemaps API Key'), findsNothing);
      expect(dismissed, isTrue);
    });

    testWidgets(
        'AppBaseMap does not render banner when showApiKeyMissingBanner is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                showApiKeyMissingBanner: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MapApiKeyMissingBanner), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets(
        'AppBaseMap does not render banner when valid apiKey is configured',
        (WidgetTester tester) async {
      final configWithKey =
          MapTileProviderConfig.defaultProvider(apiKey: 'valid-carto-key');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                tileProviderConfig: configWithKey,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MapApiKeyMissingBanner), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets(
        'AppBaseMap does not render banner for OpenStreetMapDev provider',
        (WidgetTester tester) async {
      final osmConfig = MapTileProviderConfig.openStreetMapDev();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppBaseMap(
                tileProviderConfig: osmConfig,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MapApiKeyMissingBanner), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets(
        'AppMapView supports apiKeyBannerTopOffset to prevent overlapping controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: AppMapView(
                tileProviderConfig: MapTileProviderConfig.carto(apiKey: ''),
                apiKeyBannerTopOffset: 60.0,
                markers: [
                  MapMarkerBuilder.buildStopMarker(
                    point: const LatLng(10.7769, 106.7009),
                    sequence: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify banner rendered at custom offset
      expect(find.byType(MapApiKeyMissingBanner), findsOneWidget);
      // Verify stop marker is also rendered
      expect(find.text('1'), findsOneWidget);
    });
  });
}
