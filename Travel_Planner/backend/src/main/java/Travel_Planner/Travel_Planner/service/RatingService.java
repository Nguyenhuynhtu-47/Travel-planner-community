package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.RateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.DeleteRatingResponse;
import Travel_Planner.Travel_Planner.dto.response.RatingResponse;
import Travel_Planner.Travel_Planner.dto.response.RatingSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.UserRatingStatusResponse;

public interface RatingService {
    RatingResponse rateItinerary(Integer itineraryId, RateItineraryRequest request, String currentUsername);
    UserRatingStatusResponse getUserRating(Integer itineraryId, String currentUsername);
    RatingSummaryResponse getRatingSummary(Integer itineraryId);
    DeleteRatingResponse deleteRating(Integer itineraryId, String currentUsername);
}

