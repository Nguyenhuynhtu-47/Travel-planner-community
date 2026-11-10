package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.*;
import org.springframework.data.domain.Page;

public interface PublicUserService {
    PublicProfileResponse getProfile(Integer userId, String viewerUsername);
    PublicProfileResponse getProfileByHandle(String handle, String viewerUsername);
    PageResponse<ItinerarySummaryResponse> getItineraries(Integer userId, int page, int size);
    void follow(Integer userId, String username);
    void unfollow(Integer userId, String username);
    PageResponse<PublicUserSummaryResponse> getFollowers(Integer userId, int page, int size);
    PageResponse<PublicUserSummaryResponse> getFollowing(Integer userId, int page, int size);
}
