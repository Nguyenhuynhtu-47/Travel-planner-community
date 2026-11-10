package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.ChatEventResponse;

public record CommittedChatEvent(String firstUsername, String secondUsername, ChatEventResponse payload) { }
