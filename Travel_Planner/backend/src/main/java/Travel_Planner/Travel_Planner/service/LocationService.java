package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;

import java.util.List;

public interface LocationService {
    List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude);
    List<LocationSearchResultResponse> searchNearby(Double latitude, Double longitude, String category, Integer radiusMeters, Integer limit);
    LocationSearchResultResponse reverseGeocode(Double latitude, Double longitude);
}

