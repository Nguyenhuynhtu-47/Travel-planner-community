package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.CreateActivityRequest;
import Travel_Planner.Travel_Planner.dto.request.CreateDayRequest;
import Travel_Planner.Travel_Planner.dto.request.CreateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.request.ReorderActivityItem;
import Travel_Planner.Travel_Planner.dto.request.UpdateActivityRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateDayRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.ActivityResponse;
import Travel_Planner.Travel_Planner.dto.response.ItineraryDayResponse;
import Travel_Planner.Travel_Planner.dto.response.ItineraryDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;

import java.math.BigDecimal;
import java.util.List;

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

    ItineraryDetailResponse getItineraryDetail(Integer id, String currentUsername);

    PageResponse<ItinerarySummaryResponse> getMyItineraries(
            String currentUsername,
            String status,
            String visibility,
            int page,
            int size,
            String sort
    );

    ItineraryDetailResponse createItinerary(CreateItineraryRequest request, String currentUsername);

    ItineraryDetailResponse updateItinerary(Integer id, UpdateItineraryRequest request, String currentUsername);

    void deleteItinerary(Integer id, String currentUsername);

    ItineraryDayResponse addDay(Integer itineraryId, CreateDayRequest request, String currentUsername);

    ItineraryDayResponse updateDay(Integer itineraryId, Integer dayId, UpdateDayRequest request, String currentUsername);

    void deleteDay(Integer itineraryId, Integer dayId, String currentUsername);

    ActivityResponse addActivity(Integer itineraryId, Integer dayId, CreateActivityRequest request, String currentUsername);

    ActivityResponse updateActivity(Integer itineraryId, Integer dayId, Integer activityId, UpdateActivityRequest request, String currentUsername);

    void deleteActivity(Integer itineraryId, Integer dayId, Integer activityId, String currentUsername);

    List<ActivityResponse> reorderActivities(Integer itineraryId, Integer dayId, List<ReorderActivityItem> items, String currentUsername);
}
