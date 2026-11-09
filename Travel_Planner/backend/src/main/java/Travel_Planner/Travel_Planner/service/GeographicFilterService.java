package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.location.GeographicTargetArea;
import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;

import java.util.List;

/**
 * Service for strict spatial and administrative filtering of search candidates.
 * Enforces geographic boundaries when a specific locality target is specified by the user.
 */
public interface GeographicFilterService {

    /**
     * Filters a list of candidate locations against a resolved target geographical area.
     * Candidates outside the spatial boundary or belonging to conflicting provinces are discarded.
     *
     * @param candidates raw candidates from geocoding providers
     * @param targetArea resolved target area with center, bounding box, and radius
     * @return filtered list of valid candidates inside the target area
     */
    List<LocationSearchResultResponse> filter(List<LocationSearchResultResponse> candidates, GeographicTargetArea targetArea);
}

