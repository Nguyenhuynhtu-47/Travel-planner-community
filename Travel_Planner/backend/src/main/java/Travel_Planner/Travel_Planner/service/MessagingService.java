package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.response.ConversationSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.MessagePageResponse;
import Travel_Planner.Travel_Planner.dto.response.MessageResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;

public interface MessagingService {
    ConversationSummaryResponse openDirect(Integer recipientUserId, String actorUsername);
    PageResponse<ConversationSummaryResponse> conversations(int page, int size, String actorUsername);
    MessagePageResponse messages(Long conversationId, Long beforeSequence, Long afterSequence, int size, String actorUsername);
    MessageResponse send(Long conversationId, SendMessageRequest request, String actorUsername);
    void markRead(Long conversationId, Long lastReadSequence, String actorUsername);
}
