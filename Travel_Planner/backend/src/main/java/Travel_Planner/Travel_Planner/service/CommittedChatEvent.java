package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.ChatEventResponse;

public record CommittedChatEvent(
        String firstUsername,
        Integer firstUserId,
        String secondUsername,
        Integer secondUserId,
        ChatEventResponse payload,
        boolean deliverToSecondUser) {
    public CommittedChatEvent(String firstUsername, Integer firstUserId,
            String secondUsername, Integer secondUserId, ChatEventResponse payload) {
        this(firstUsername, firstUserId, secondUsername, secondUserId, payload, true);
    }
}
