package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.EmailChangeRequestDto;
import Travel_Planner.Travel_Planner.dto.request.EmailChangeVerifyDto;
import Travel_Planner.Travel_Planner.dto.response.EmailChangeResponse;

public interface EmailChangeService {

    EmailChangeResponse requestEmailChange(String currentUsername, EmailChangeRequestDto request);

    EmailChangeResponse verifyEmailChange(String currentUsername, EmailChangeVerifyDto request);
}
