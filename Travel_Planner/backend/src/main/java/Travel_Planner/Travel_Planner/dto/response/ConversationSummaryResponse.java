package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ConversationSummaryResponse {
    private Long conversationId;
    private PublicUserSummaryResponse peer;
    private MessageResponse lastMessage;
    private Long lastMessageSequence;
    private long unreadCount;
    private boolean canSendMessage;
    private LocalDateTime updatedAt;
}
