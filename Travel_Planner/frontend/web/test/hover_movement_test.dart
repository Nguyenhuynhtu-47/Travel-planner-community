import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_web/shared/widgets/hover_movement.dart';

void main() {
  group('HoverMovement Widget & Subtle Motion Tests', () {
    testWidgets('HoverMovement.button translates upward by -1.5px on hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoverMovement.button(
                child: const SizedBox(
                  key: ValueKey('test-button'),
                  width: 100,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the AnimatedContainer
      final animContainerFinder = find.byType(AnimatedContainer);
      expect(animContainerFinder, findsOneWidget);

      AnimatedContainer container = tester.widget(animContainerFinder);
      // Initially, transform has translation (0, 0, 0)
      Matrix4 transform = container.transform ?? Matrix4.identity();
      expect(transform.getTranslation().y, equals(0.0));
      expect(transform.getTranslation().x, equals(0.0));

      // Simulate mouse hover enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('test-button'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      container = tester.widget(animContainerFinder);
      transform = container.transform ?? Matrix4.identity();
      expect(transform.getTranslation().y, equals(-1.5));
      expect(transform.getTranslation().x, equals(0.0));

      // Simulate mouse exit
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      container = tester.widget(animContainerFinder);
      transform = container.transform ?? Matrix4.identity();
      expect(transform.getTranslation().y, equals(0.0));
      expect(transform.getTranslation().x, equals(0.0));
    });

    testWidgets('HoverMovement.slide translates horizontally by 2.0px on hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoverMovement.slide(
                child: const SizedBox(
                  key: ValueKey('test-slide'),
                  width: 200,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animContainerFinder = find.byType(AnimatedContainer);
      expect(animContainerFinder, findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('test-slide'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      AnimatedContainer container = tester.widget(animContainerFinder);
      Matrix4 transform = container.transform ?? Matrix4.identity();
      expect(transform.getTranslation().x, equals(2.0));
      expect(transform.getTranslation().y, equals(0.0));

      // Exit
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      container = tester.widget(animContainerFinder);
      transform = container.transform ?? Matrix4.identity();
      expect(transform.getTranslation().x, equals(0.0));
      expect(transform.getTranslation().y, equals(0.0));
    });

    testWidgets('HoverMovement.card translates upward by -2.0px on hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoverMovement.card(
                child: const SizedBox(
                  key: ValueKey('test-card'),
                  width: 200,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('test-card'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      AnimatedContainer container = tester.widget(find.byType(AnimatedContainer));
      Matrix4 transform = container.transform ?? Matrix4.identity();
      expect(transform.getTranslation().y, equals(-2.0));
      expect(transform.getTranslation().x, equals(0.0));
    });
  });
}
