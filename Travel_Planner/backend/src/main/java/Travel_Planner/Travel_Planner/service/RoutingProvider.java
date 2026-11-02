package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.model.CachedRouteResult;
import Travel_Planner.Travel_Planner.model.WaypointCoordinate;

import java.util.List;

/**
 * Provider-agnostic routing interface.
 * Encapsulates communication with external road network routing engines (e.g. OpenRouteService).
 */
public interface RoutingProvider {

    /**
     * Identifies the active routing provider name (e.g. "OPEN_ROUTE_SERVICE").
     */
    String getProviderName();

    /**
     * Checks whether the provider has a valid API key and configuration.
     */
    boolean isConfigured();

    /**
     * Requests a road route calculation for the ordered list of waypoints.
     *
     * @param mode Travel mode, e.g. "driving" or "walking"
     * @param waypoints Ordered list of geographic coordinates
     * @return Normalized {@link CachedRouteResult}
     */
    CachedRouteResult calculateRoute(String mode, List<WaypointCoordinate> waypoints);
}

