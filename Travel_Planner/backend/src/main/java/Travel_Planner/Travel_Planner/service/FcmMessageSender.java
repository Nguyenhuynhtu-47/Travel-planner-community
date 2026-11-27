package Travel_Planner.Travel_Planner.service;

import java.util.Map;

public interface FcmMessageSender {
    void send(String token, String title, String body, String conversationId, String collapseKey);
    void sendNotification(String token, String title, String body, Map<String, String> data, String collapseKey);
    boolean isInvalidRegistration(RuntimeException exception);
}
