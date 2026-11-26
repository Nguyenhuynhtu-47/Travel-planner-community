package Travel_Planner.Travel_Planner.service;

import java.util.List;

public record CommittedMessagePush(String title, String body, String conversationId,
        String collapseKey, List<DevicePushToken> tokens) {
    public record DevicePushToken(Long id, String token) { }
}
