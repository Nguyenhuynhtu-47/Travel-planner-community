package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.SavePlaceToItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.ItineraryPlaceResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface ItineraryPlaceService {

    ItineraryPlaceResponse savePlaceToItinerary(Integer itineraryId, SavePlaceToItineraryRequest request, String currentUsernameOrEmail);

    Page<ItineraryPlaceResponse> getSavedPlaces(Integer itineraryId, Pageable pageable, String currentUsernameOrEmail);

    List<ItineraryPlaceResponse> getAllSavedPlaces(Integer itineraryId, String currentUsernameOrEmail);

    void removePlaceFromItinerary(Integer itineraryId, Long placeId, String currentUsernameOrEmail);

    boolean isPlaceSavedInItinerary(Integer itineraryId, Long placeId);
}
