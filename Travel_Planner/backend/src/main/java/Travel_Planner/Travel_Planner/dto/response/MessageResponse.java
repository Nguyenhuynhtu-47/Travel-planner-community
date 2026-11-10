package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class MessageResponse {
    private Long messageId;
    private Long conversationId;
    private Long sequenceNumber;
    private Integer senderUserId;
    private String senderHandle;
    private String senderName;
    private String senderAvatar;
    private String clientMessageId;
    private String content;
    private LocalDateTime createdAt;
}
