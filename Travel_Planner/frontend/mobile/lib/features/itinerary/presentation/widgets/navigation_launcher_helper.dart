import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

typedef UrlLauncherFn = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Represents a geographical point with an optional semantic display label for navigation deep links.
class NavigationStop {
  final LatLng point;
  final String? label;

  const NavigationStop({
    required this.point,
    this.label,
  });

  /// Factory helper from [LatLng] coordinate and optional [label].
  factory NavigationStop.fromPoint(LatLng point, [String? label]) =>
      NavigationStop(point: point, label: label);

  @override
  String toString() => 'NavigationStop(point: $point, label: $label)';
}

/// Helper utility for generating and launching free, external Google Maps navigation intents.
///
/// Uses the universal Google Maps URL scheme without requiring any API keys or paid SDKs:
/// - Single stop: Opens place view / search via `https://www.google.com/maps/search/?api=1&query=...`
/// - Multiple stops: Opens turn-by-turn navigation via `https://www.google.com/maps/dir/?api=1&origin=...&destination=...&waypoints=...`
class NavigationLauncherHelper {
  NavigationLauncherHelper._();

  static const int maxIntermediateWaypoints = 9;

  /// Formats a coordinate with an optional label for Google Maps URL parameters.
  /// If [label] is present and non-empty, produces `lat,lon(sanitizedLabel)`.
  /// Otherwise, returns plain `lat,lon`.
  static String formatPointParam(LatLng point, String? label) {
    final lat = point.latitude;
    final lon = point.longitude;
    final cleanLabel = _sanitizeLabel(label);
    if (cleanLabel != null && cleanLabel.isNotEmpty) {
      return '$lat,$lon($cleanLabel)';
    }
    return '$lat,$lon';
  }

  /// Sanitizes label string: trims whitespace and normalizes nested parentheses to brackets
  /// to ensure the outer `(label)` syntax in Google Maps URLs remains balanced and unambiguous.
  static String? _sanitizeLabel(String? label) {
    if (label == null) return null;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.replaceAll('(', '[').replaceAll(')', ']');
  }

  /// Builds a standard, keyless Google Maps directions or search URL for the given ordered stops.
  ///
  /// Accepts either rich [stops] (with coordinates and display names) or legacy [waypoints] (coordinates only).
  /// Coordinates remain the authoritative navigation target; display labels provide human-readable names.
  ///
  /// Returns `null` if both [stops] and [waypoints] are empty or null.
  static Uri? buildGoogleMapsUri({
    List<NavigationStop>? stops,
    List<LatLng>? waypoints,
    String mode = 'driving',
  }) {
    final effectiveStops = stops ??
        waypoints?.map((wp) => NavigationStop(point: wp)).toList() ??
        const [];

    if (effectiveStops.isEmpty) return null;

    final travelMode = switch (mode.toLowerCase()) {
      'walking' || 'walk' || 'foot-walking' => 'walking',
      'bicycling' || 'cycling' || 'bike' || 'cycling-regular' => 'bicycling',
      'transit' => 'transit',
      _ => 'driving',
    };

    // Single stop: open search / place view with label
    if (effectiveStops.length == 1) {
      final stop = effectiveStops.first;
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': formatPointParam(stop.point, stop.label),
      });
    }

    // Two or more stops: construct directions route
    final origin = effectiveStops.first;
    final destination = effectiveStops.last;

    final queryParams = <String, String>{
      'api': '1',
      'origin': formatPointParam(origin.point, origin.label),
      'destination': formatPointParam(destination.point, destination.label),
      'travelmode': travelMode,
    };

    if (effectiveStops.length > 2) {
      final intermediate = effectiveStops.sublist(1, effectiveStops.length - 1);
      final limitedIntermediate = intermediate.length > maxIntermediateWaypoints
          ? intermediate.sublist(0, maxIntermediateWaypoints)
          : intermediate;

      final waypointsStr = limitedIntermediate
          .map((wp) => formatPointParam(wp.point, wp.label))
          .join('|');

      queryParams['waypoints'] = waypointsStr;
    }

    return Uri.https('www.google.com', '/maps/dir/', queryParams);
  }

  /// Launches Google Maps externally.
  ///
  /// Displays a non-intrusive [SnackBar] if the intent cannot be launched.
  static Future<bool> launchNavigation({
    required BuildContext context,
    List<NavigationStop>? stops,
    List<LatLng>? waypoints,
    String mode = 'driving',
    UrlLauncherFn launcher = launchUrl,
  }) async {
    final effectiveStops = stops ??
        waypoints?.map((wp) => NavigationStop(point: wp)).toList() ??
        const [];

    final uri = buildGoogleMapsUri(stops: effectiveStops, mode: mode);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có điểm dừng nào có tọa độ để chỉ đường.'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
      return false;
    }

    if (effectiveStops.length > 2 + maxIntermediateWaypoints && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Maps giới hạn tối đa 9 điểm trung gian. Đã chọn 11 điểm đầu tiên.',
          ),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      final launched = await launcher(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng Google Maps trên thiết bị này.'),
            backgroundColor: AppColors.error,
          ),
        );
      }

      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xảy ra lỗi khi mở Google Maps.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }
}
