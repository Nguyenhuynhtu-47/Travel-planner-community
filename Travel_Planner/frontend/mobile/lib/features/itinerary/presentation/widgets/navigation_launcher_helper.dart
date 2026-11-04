import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

typedef UrlLauncherFn = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Helper utility for generating and launching free, external Google Maps navigation intents.
///
/// Uses the universal Google Maps URL scheme without requiring any API keys or paid SDKs:
/// - Single stop: Opens place view / search via `https://www.google.com/maps/search/?api=1&query=...`
/// - Multiple stops: Opens turn-by-turn navigation via `https://www.google.com/maps/dir/?api=1&origin=...&destination=...&waypoints=...`
class NavigationLauncherHelper {
  NavigationLauncherHelper._();

  static const int maxIntermediateWaypoints = 9;

  /// Builds a standard, keyless Google Maps directions or search URL for the given ordered coordinates.
  ///
  /// Returns `null` if [waypoints] is empty.
  static Uri? buildGoogleMapsUri({
    required List<LatLng> waypoints,
    String mode = 'driving',
  }) {
    if (waypoints.isEmpty) return null;

    final travelMode = switch (mode.toLowerCase()) {
      'walking' || 'walk' || 'foot-walking' => 'walking',
      'bicycling' || 'cycling' || 'bike' || 'cycling-regular' => 'bicycling',
      'transit' => 'transit',
      _ => 'driving',
    };

    // Single stop: open search / place view
    if (waypoints.length == 1) {
      final stop = waypoints.first;
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${stop.latitude},${stop.longitude}',
      });
    }

    // Two or more stops: construct directions route
    final origin = waypoints.first;
    final destination = waypoints.last;

    final queryParams = <String, String>{
      'api': '1',
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': travelMode,
    };

    if (waypoints.length > 2) {
      final intermediate = waypoints.sublist(1, waypoints.length - 1);
      final limitedIntermediate = intermediate.length > maxIntermediateWaypoints
          ? intermediate.sublist(0, maxIntermediateWaypoints)
          : intermediate;

      final waypointsStr = limitedIntermediate
          .map((wp) => '${wp.latitude},${wp.longitude}')
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
    required List<LatLng> waypoints,
    String mode = 'driving',
    UrlLauncherFn launcher = launchUrl,
  }) async {
    final uri = buildGoogleMapsUri(waypoints: waypoints, mode: mode);
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

    if (waypoints.length > 2 + maxIntermediateWaypoints && context.mounted) {
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
