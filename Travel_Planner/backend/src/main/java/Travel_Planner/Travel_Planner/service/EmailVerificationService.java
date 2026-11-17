package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.ResendVerificationRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.ResendVerificationResponse;
import Travel_Planner.Travel_Planner.model.User;

public interface EmailVerificationService {
    void createVerificationTokenAndDispatch(User user);
    AuthResponse verifyEmail(VerifyEmailRequest request);
    ResendVerificationResponse resendVerification(ResendVerificationRequest request);
}
