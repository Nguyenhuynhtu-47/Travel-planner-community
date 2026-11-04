import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travel_planner_web/core/constants/map_constants.dart';
import 'package:travel_planner_web/shared/widgets/web_map_view.dart';

void main() {
  group('Flutter Web - CARTO Basemaps API Key Unit Tests', () {
    test('appendApiKey returns template unchanged when key is empty or null', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      expect(MapConstants.appendApiKey(template, apiKey: null), equals(template));
      expect(MapConstants.appendApiKey(template, apiKey: ''), equals(template));
      expect(MapConstants.appendApiKey(template, apiKey: '  '), equals(template));
    });

    test('appendApiKey appends ?key= when URL has no query parameters', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      final result = MapConstants.appendApiKey(template, apiKey: 'web-carto-key');
      expect(
        result,
        equals(
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=web-carto-key',
        ),
      );
    });

    test('appendApiKey appends &key= when URL has query parameters', () {
      const template = 'https://example.com/tiles/{z}/{x}/{y}.png?layer=standard';
      final result = MapConstants.appendApiKey(template, apiKey: 'key_123');
      expect(
        result,
        equals('https://example.com/tiles/{z}/{x}/{y}.png?layer=standard&key=key_123'),
      );
    });

    test('appendApiKey replaces {key} and {apiKey} placeholders', () {
      const template1 = 'https://example.com/tiles/{z}/{x}/{y}.png?token={key}';
      expect(
        MapConstants.appendApiKey(template1, apiKey: 'tok1'),
        equals('https://example.com/tiles/{z}/{x}/{y}.png?token=tok1'),
      );

      const template2 = 'https://example.com/tiles/{z}/{x}/{y}.png?token={apiKey}';
      expect(
        MapConstants.appendApiKey(template2, apiKey: 'tok2'),
        equals('https://example.com/tiles/{z}/{x}/{y}.png?token=tok2'),
      );
    });

    test('appendApiKey does not duplicate key when already present in template', () {
      const template =
          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=preconfigured';
      expect(
        MapConstants.appendApiKey(template, apiKey: 'ignored_key'),
        equals(template),
      );
    });

    test('isCartoApiKeyMissing reports true in unconfigured test environment', () {
      expect(MapConstants.hasCartoApiKey, isFalse);
      expect(MapConstants.isCartoApiKeyMissing, isTrue);
    });
  });

  group('Flutter Web - WebMapView API Key Banner Widget Tests', () {
    testWidgets(
        'WebMapView displays missing API key banner and instructions when unconfigured',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: WebMapView(),
            ),
          ),
        ),
      );

      // Verify canvas rendered
      expect(find.byType(FlutterMap), findsOneWidget);

      // Verify missing API key banner rendered
      expect(
        find.text('Chưa cấu hình CARTO Basemaps API Key'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Bản đồ nền yêu cầu API Key. Khởi chạy với: --dart-define=CARTO_API_KEY=<key>',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Lấy key miễn phí tại carto.com/basemaps/apikey'),
        findsOneWidget,
      );
    });

    testWidgets(
        'WebMapView missing API key banner can be dismissed via close button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: WebMapView(),
            ),
          ),
        ),
      );

      expect(
        find.text('Chưa cấu hình CARTO Basemaps API Key'),
        findsOneWidget,
      );

      // Tap close button on banner
      await tester.tap(find.byTooltip('Đóng thông báo'));
      await tester.pump();

      expect(
        find.text('Chưa cấu hình CARTO Basemaps API Key'),
        findsNothing,
      );
    });

    testWidgets(
        'WebMapView renders markers and controls alongside missing API key banner',
        (WidgetTester tester) async {
      final marker = Marker(
        point: const LatLng(10.7769, 106.7009),
        child: const Icon(Icons.place, color: Colors.red),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: WebMapView(
                markers: [marker],
                showControls: true,
              ),
            ),
          ),
        ),
      );

      // Verify marker is rendered
      expect(find.byIcon(Icons.place), findsOneWidget);

      // Verify zoom controls are rendered
      expect(find.byTooltip('Phóng to'), findsOneWidget);
      expect(find.byTooltip('Thu nhỏ'), findsOneWidget);

      // Verify attribution is rendered
      expect(find.text(MapConstants.tileAttribution), findsOneWidget);
    });
  });
}
