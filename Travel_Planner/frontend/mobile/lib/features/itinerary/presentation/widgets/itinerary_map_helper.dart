import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/map_marker_builder.dart';
import '../../data/models/activity_detail.dart';
import '../../data/models/itinerary_day_detail.dart';
import '../../data/models/itinerary_detail.dart';

/// Represents an activity with verified geographical coordinates mapped for display.
class MappedActivityStop {
  final ActivityDetail activity;
  final ItineraryDayDetail day;
  final int sequence; // 1-based order within its day
  final LatLng point;

  const MappedActivityStop({
    required this.activity,
    required this.day,
    required this.sequence,
    required this.point,
  });

  @override
  String toString() =>
      'MappedActivityStop(name: ${activity.name}, day: ${day.dayNumber}, seq: $sequence, point: $point)';
}

/// Helper methods for transforming itinerary and activity models into map data,
/// coordinates, bounds, and markers without coupling business logic to map rendering.
class ItineraryMapHelper {
  ItineraryMapHelper._();

  /// Palette of distinct, accessible colors for differentiating days on the map.
  static const List<Color> dayColors = [
    AppColors.primary, // Day 1: Rausch #FF385C
    Color(0xFF2563EB), // Day 2: Blue
    Color(0xFF059669), // Day 3: Emerald
    Color(0xFFD97706), // Day 4: Amber
    Color(0xFF7C3AED), // Day 5: Violet
    Color(0xFFDB2777), // Day 6: Pink
    Color(0xFF0891B2), // Day 7: Cyan
    Color(0xFF4F46E5), // Day 8: Indigo
  ];

  /// Returns a consistent color for a given day number.
  static Color getDayColor(int dayNumber) {
    if (dayNumber <= 0) return AppColors.primary;
    final index = (dayNumber - 1) % dayColors.length;
    return dayColors[index];
  }

  /// Validates whether a latitude and longitude pair is non-null, finite, and within legal Earth bounds.
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lat.isInfinite || lng.isNaN || lng.isInfinite) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Extracts all mapped stops from the itinerary for the selected day number.
  ///
  /// If [selectedDayNumber] is null, extracts stops across all days in the itinerary.
  /// Stops are ordered strictly by the day's actual order and activity display order.
  static List<MappedActivityStop> extractMappedStops(
    ItineraryDetail itinerary, {
    int? selectedDayNumber,
  }) {
    final stops = <MappedActivityStop>[];

    final daysToProcess = selectedDayNumber == null
        ? itinerary.days
        : itinerary.days.where((d) => d.dayNumber == selectedDayNumber).toList();

    for (final day in daysToProcess) {
      for (var i = 0; i < day.activities.length; i++) {
        final activity = day.activities[i];
        final lat = activity.effectiveLatitude;
        final lng = activity.effectiveLongitude;

        if (isValidCoordinate(lat, lng)) {
          stops.add(
            MappedActivityStop(
              activity: activity,
              day: day,
              sequence: i + 1,
              point: LatLng(lat!, lng!),
            ),
          );
        }
      }
    }

    return stops;
  }

  /// Calculates the count of activities that do not have valid coordinates
  /// for the currently selected day (or across all days if [selectedDayNumber] is null).
  static int countMissingCoordinates(
    ItineraryDetail itinerary, {
    int? selectedDayNumber,
  }) {
    var missingCount = 0;

    final daysToProcess = selectedDayNumber == null
        ? itinerary.days
        : itinerary.days.where((d) => d.dayNumber == selectedDayNumber).toList();

    for (final day in daysToProcess) {
      for (final activity in day.activities) {
        if (!isValidCoordinate(
          activity.effectiveLatitude,
          activity.effectiveLongitude,
        )) {
          missingCount++;
        }
      }
    }

    return missingCount;
  }

  /// Calculates total activity count for the currently selected day (or all days).
  static int countTotalActivities(
    ItineraryDetail itinerary, {
    int? selectedDayNumber,
  }) {
    final daysToProcess = selectedDayNumber == null
        ? itinerary.days
        : itinerary.days.where((d) => d.dayNumber == selectedDayNumber).toList();

    var total = 0;
    for (final day in daysToProcess) {
      total += day.activities.length;
    }
    return total;
  }

  /// Builds a list of [Marker] objects for the given mapped stops using [MapMarkerBuilder].
  ///
  /// When [isMultiDay] is true, stops display day pill badges (`D1`, `D2`) and day-specific colors.
  static List<Marker> buildActivityMarkers({
    required List<MappedActivityStop> stops,
    bool isMultiDay = false,
    ActivityDetail? selectedActivity,
    void Function(MappedActivityStop stop)? onStopTapped,
  }) {
    return stops.map((stop) {
      final isSelected = selectedActivity?.activityId == stop.activity.activityId;
      final pinColor = isMultiDay
          ? getDayColor(stop.day.dayNumber)
          : AppColors.primary;

      return MapMarkerBuilder.buildStopMarker(
        point: stop.point,
        sequence: stop.sequence,
        dayBadge: isMultiDay ? 'D${stop.day.dayNumber}' : null,
        pinColor: isSelected ? const Color(0xFF1E293B) : pinColor,
        textColor: Colors.white,
        semanticLabel:
            '${stop.activity.name} - Ngày ${stop.day.dayNumber}, điểm số ${stop.sequence}',
        onTap: onStopTapped != null ? () => onStopTapped(stop) : null,
      );
    }).toList();
  }

  /// Computes a user-friendly missing-coordinates notice string.
  ///
  /// Returns null if all activities have coordinates or if there are no activities.
  static String? getMissingCoordinatesMessage(
    ItineraryDetail itinerary, {
    int? selectedDayNumber,
  }) {
    final total = countTotalActivities(itinerary, selectedDayNumber: selectedDayNumber);
    if (total == 0) return null;

    final missing = countMissingCoordinates(
      itinerary,
      selectedDayNumber: selectedDayNumber,
    );

    if (missing == 0) return null;

    if (missing == total) {
      return 'Chưa có hoạt động nào có vị trí trên bản đồ';
    }

    return '$missing hoạt động chưa có vị trí trên bản đồ';
  }
}

