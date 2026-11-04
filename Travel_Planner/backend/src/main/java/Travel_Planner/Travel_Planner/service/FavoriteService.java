package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.FavoriteResponse;
import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;

public interface FavoriteService {
    FavoriteResponse addFavorite(Integer itineraryId, String currentUsername);
    FavoriteResponse removeFavorite(Integer itineraryId, String currentUsername);
    PageResponse<ItinerarySummaryResponse> getUserFavorites(String currentUsername, int page, int size);
}

