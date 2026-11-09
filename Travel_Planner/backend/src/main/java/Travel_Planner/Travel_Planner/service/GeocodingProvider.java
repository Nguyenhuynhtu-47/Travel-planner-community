package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;

import java.util.List;

public interface GeocodingProvider {
    String getProviderName();
    boolean isConfigured();
    List<LocationSearchResultResponse> search(String query, int limit, Double latitude, Double longitude);
    default List<LocationSearchResultResponse> searchInArea(String query, int limit, Double latitude, Double longitude, List<Double> boundingBox, Integer radiusMeters) {
        return search(query, limit, latitude, longitude);
    }
    List<LocationSearchResultResponse> searchNearby(double latitude, double longitude, String category, int radiusMeters, int limit);
    LocationSearchResultResponse reverseGeocode(double latitude, double longitude);
}

