package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.GoogleAuthRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleLinkRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.GoogleLinkResponse;

public interface GoogleAuthService {

    /**
     * Authenticates a user using a verified Google ID Token.
     * Logs in existing linked users, or provisions new users.
     * Rejects unlinked tokens whose email matches an existing local user with HTTP 409 Conflict.
     *
     * @param request the request containing raw Google ID token
     * @return Travel Planner JWT AuthResponse
     */
    AuthResponse authenticateWithGoogle(GoogleAuthRequest request);

    /**
     * Links an authenticated Travel Planner user account to a Google account.
     * Rejects if the Google account is already linked to another user.
     *
     * @param currentUsername username of the currently logged-in user
     * @param request the request containing raw Google ID token
     * @return link confirmation details
     */
    GoogleLinkResponse linkGoogleAccount(String currentUsername, GoogleLinkRequest request);
}
