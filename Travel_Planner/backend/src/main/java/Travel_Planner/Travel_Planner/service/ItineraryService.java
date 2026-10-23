package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;

import java.math.BigDecimal;

public interface ItineraryService {

    PageResponse<ItinerarySummaryResponse> getPublicItineraries(
            String keyword,
            String location,
            String theme,
            BigDecimal minBudget,
            BigDecimal maxBudget,
            Integer minDays,
            Integer maxDays,
            Double minRating,
            int page,
            int size,
            String sort
    );

    Travel_Planner.Travel_Planner.dto.response.ItineraryDetailResponse getItineraryDetail(Integer id, String currentUsername);
}
