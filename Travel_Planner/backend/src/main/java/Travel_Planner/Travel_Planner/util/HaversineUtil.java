package Travel_Planner.Travel_Planner.util;

import Travel_Planner.Travel_Planner.model.WaypointCoordinate;

import java.util.List;

/**
 * Utility for computing great-circle straight-line distances using the Haversine formula.
 */
public final class HaversineUtil {

    private static final double EARTH_RADIUS_METERS = 6371000.0;

    private HaversineUtil() {}

    /**
     * Calculates the great-circle distance between two geographic coordinates in meters.
     */
    public static double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double rLat1 = Math.toRadians(lat1);
        double rLat2 = Math.toRadians(lat2);

        double a = Math.sin(dLat / 2.0) * Math.sin(dLat / 2.0)
                + Math.cos(rLat1) * Math.cos(rLat2)
                * Math.sin(dLon / 2.0) * Math.sin(dLon / 2.0);
        double c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));

        return Math.round(EARTH_RADIUS_METERS * c * 10.0) / 10.0;
    }

    /**
     * Calculates the cumulative direct straight-line distance across an ordered series of waypoints.
     */
    public static double calculateTotalDirectDistanceMeters(List<WaypointCoordinate> waypoints) {
        if (waypoints == null || waypoints.size() < 2) {
            return 0.0;
        }
        double total = 0.0;
        for (int i = 0; i < waypoints.size() - 1; i++) {
            WaypointCoordinate p1 = waypoints.get(i);
            WaypointCoordinate p2 = waypoints.get(i + 1);
            total += calculateDistanceMeters(p1.latitude(), p1.longitude(), p2.latitude(), p2.longitude());
        }
        return Math.round(total * 10.0) / 10.0;
    }
}

