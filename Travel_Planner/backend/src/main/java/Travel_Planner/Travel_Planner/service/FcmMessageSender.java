package Travel_Planner.Travel_Planner.service;

public interface FcmMessageSender {
    void send(String token, String title, String body, String conversationId, String collapseKey);
    boolean isInvalidRegistration(RuntimeException exception);
}
