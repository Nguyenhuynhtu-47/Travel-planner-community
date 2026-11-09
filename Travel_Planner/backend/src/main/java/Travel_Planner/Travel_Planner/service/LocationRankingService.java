package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import java.util.List;

/**
 * Service responsible for semantically ranking, filtering, and deduplicating
 * location search results from one or more geocoding providers.
 */
public interface LocationRankingService {

    List<LocationSearchResultResponse> rankAndDeduplicate(
            String query,
            List<LocationSearchResultResponse> results,
            Double viewportLat,
            Double viewportLon,
            int limit
    );
}

