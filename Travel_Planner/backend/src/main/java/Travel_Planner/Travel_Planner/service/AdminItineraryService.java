package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.ModerateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.ItineraryAdminDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.ItineraryAdminResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;

public interface AdminItineraryService {

    PageResponse<ItineraryAdminResponse> getAdminItineraries(
            String keyword,
            ItineraryStatus status,
            Visibility visibility,
            int page,
            int size,
            String sort);

    ItineraryAdminDetailResponse getAdminItineraryById(
            Integer itineraryId,
            Long reportId,
            String inspectionReason,
            String actorUsername);

    ItineraryAdminResponse moderateItinerary(
            Integer itineraryId,
            ModerateItineraryRequest request,
            String actorUsername);
}
