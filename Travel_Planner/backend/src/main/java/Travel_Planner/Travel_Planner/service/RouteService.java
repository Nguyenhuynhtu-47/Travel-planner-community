package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.RouteResponse;

/**
 * Service for calculating and retrieving per-day travel routes between itinerary stops.
 */
public interface RouteService {

    /**
     * Calculates the road route for a given day in an itinerary.
     *
     * @param itineraryId ID of the itinerary
     * @param dayId ID of the day within the itinerary
     * @param mode Travel mode ("driving" or "walking")
     * @param currentUsername Authenticated user's username
     * @return Normalized {@link RouteResponse}
     */
    RouteResponse calculateDayRoute(Integer itineraryId, Integer dayId, String mode, String currentUsername);
}

