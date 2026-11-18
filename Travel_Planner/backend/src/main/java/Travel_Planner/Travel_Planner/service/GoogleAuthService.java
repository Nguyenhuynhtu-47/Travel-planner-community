package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.GoogleAuthRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleLinkRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.GoogleLinkResponse;

public interface GoogleAuthService {
    AuthResponse authenticateWithGoogle(GoogleAuthRequest request);
    AuthResponse authenticateWithGoogle(GoogleAuthRequest request, String deviceInfo, String ipAddress);
    GoogleLinkResponse linkGoogleAccount(String currentUsername, GoogleLinkRequest request);
}
