package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.SavedItineraryResponse;

public interface SavedItineraryService {
    SavedItineraryResponse saveItinerary(Integer itineraryId, String currentUsername);
    SavedItineraryResponse removeSavedItinerary(Integer itineraryId, String currentUsername);
    PageResponse<ItinerarySummaryResponse> getUserSavedItineraries(String currentUsername, int page, int size);
}

