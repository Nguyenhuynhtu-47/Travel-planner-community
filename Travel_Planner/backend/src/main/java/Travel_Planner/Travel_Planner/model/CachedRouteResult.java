package Travel_Planner.Travel_Planner.model;

import java.io.Serializable;
import java.util.List;

/**
 * Normalized route result returned by routing providers (or Haversine fallback)
 * and stored in the Caffeine route cache.
 *
 * <p>Strictly decoupled from domain and user entities. Contains ONLY routing
 * provider calculation output (geometry, road distance, duration) and Haversine
 * straight-line metrics. Never contains Activity, Itinerary, or User identifiers.</p>
 */
public record CachedRouteResult(
    String routeType,            // "ACTUAL_ROAD" or "ESTIMATED_INDICATIVE"
    String provider,             // "OPEN_ROUTE_SERVICE" or "LOCAL_HAVERSINE"
    Double totalDistanceMeters,  // e.g. 4250.0 (null for Haversine)
    Double directDistanceMeters, // e.g. 3800.0 (always computed via Haversine)
    Double totalDurationSeconds, // e.g. 720.0 (null for Haversine)
    List<List<Double>> geometryCoordinates // [[lng1, lat1], [lng2, lat2], ...]
) implements Serializable {}

