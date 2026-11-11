package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;

import java.math.BigDecimal;

public interface PlaceNormalizationService {

    String normalizeText(String input);

    String normalizeAddress(String address);

    boolean isProtectedCompoundName(String name);

    boolean isDifferentBranch(String name1, String name2, String addr1, String addr2, double distanceMeters);

    double calculateMatchConfidence(Place existingPlace,
                                    String incomingName,
                                    String incomingAddress,
                                    BigDecimal incomingLat,
                                    BigDecimal incomingLon,
                                    PlaceCategory incomingCategory);

    PlaceCategory mapProviderCategory(String rawCategory, String rawType);

    double haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2);
}

