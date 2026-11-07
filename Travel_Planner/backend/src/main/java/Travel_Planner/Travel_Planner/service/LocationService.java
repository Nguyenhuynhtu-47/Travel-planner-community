package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;

import java.util.List;

public interface LocationService {
    List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude);
    List<LocationSearchResultResponse> searchLocations(String query, Integer limit, Double latitude, Double longitude, String provider, String sessionId);
    List<LocationSearchResultResponse> searchLocationsUnified(String query, Integer limit, String mode, String sessionId);
    LocationSearchResultResponse resolveTomTomPlace(String type, String id, String sessionId);
    List<LocationSearchResultResponse> searchNearby(Double latitude, Double longitude, String category, Integer radiusMeters, Integer limit);
    LocationSearchResultResponse reverseGeocode(Double latitude, Double longitude);
}

