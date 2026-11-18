package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.UserSessionResponse;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserSession;

import java.util.List;

public interface UserSessionService {

    UserSession createSession(User user, String deviceInfo, String ipAddress, long expirationMs);

    boolean isSessionActive(String sessionId);

    void touchSession(String sessionId);

    void revokeSession(String sessionId, String currentUsername);

    int revokeOtherSessions(String currentUsername, String currentSessionId);

    int revokeAllSessions(String currentUsername);

    List<UserSessionResponse> getUserSessions(String currentUsername, String currentSessionId);

    void revokeCurrentSession(String sessionId);
}
