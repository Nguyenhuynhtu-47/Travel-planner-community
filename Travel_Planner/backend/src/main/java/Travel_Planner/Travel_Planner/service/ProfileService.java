package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.UpdateProfileRequest;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;

public interface ProfileService {

    UserResponse getCurrentProfile(String username);

    UserResponse updateCurrentProfile(String username, UpdateProfileRequest request);
}
