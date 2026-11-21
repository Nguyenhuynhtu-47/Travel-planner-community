package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.request.ShareBatchRequest;
import Travel_Planner.Travel_Planner.dto.response.ConversationSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.MessagePageResponse;
import Travel_Planner.Travel_Planner.dto.response.MessageResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.ShareBatchResponse;

public interface MessagingService {
    ConversationSummaryResponse openDirect(Integer recipientUserId, String actorUsername);
    PageResponse<ConversationSummaryResponse> conversations(int page, int size, String actorUsername);
    PageResponse<ConversationSummaryResponse> messageRequests(int page, int size, String actorUsername);
    long pendingMessageRequestCount(String actorUsername);
    long unreadMessageRequestCount(String actorUsername);
    ConversationSummaryResponse acceptMessageRequest(Long conversationId, String actorUsername);
    ConversationSummaryResponse declineMessageRequest(Long conversationId, String actorUsername);
    MessagePageResponse messages(Long conversationId, Long beforeSequence, Long afterSequence, int size, String actorUsername);
    MessageResponse send(Long conversationId, SendMessageRequest request, String actorUsername);
    ShareBatchResponse shareContent(ShareBatchRequest request, String actorUsername);
    void markRead(Long conversationId, Long lastReadSequence, String actorUsername);
    long totalUnread(String actorUsername);
}
