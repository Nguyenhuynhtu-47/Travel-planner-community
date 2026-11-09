import 'package:flutter/material.dart';

/// Reusable text scale for community surfaces, based on DESIGN.md.
abstract final class AppTextStyles {
  static const TextStyle displaySm = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bodyMd = TextStyle(fontSize: 16, height: 1.5);
  static const TextStyle bodySm = TextStyle(fontSize: 14, height: 1.43);
  static const TextStyle caption = TextStyle(fontSize: 13, height: 1.3);
  static const TextStyle buttonSm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
