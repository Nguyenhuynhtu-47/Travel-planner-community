package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ConversationSummaryResponse {
    private Long conversationId;
    private PublicUserSummaryResponse peer;
    private MessageResponse lastMessage;
    private Long lastMessageSequence;
    private long unreadCount;
    private boolean canSendMessage;
    private ConversationStatus status;
    private boolean canRespondToMessageRequest;
    private boolean recipientPrivacyRestricted;
    private LocalDateTime requestAvailableAt;
    private LocalDateTime updatedAt;
}
