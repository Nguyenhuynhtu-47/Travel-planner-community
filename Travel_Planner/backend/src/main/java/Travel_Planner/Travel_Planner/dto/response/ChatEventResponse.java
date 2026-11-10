package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class ChatEventResponse {
    private String eventId;
    private String type;
    private LocalDateTime occurredAt;
    private Long conversationId;
    private Long sequenceNumber;
    private MessageResponse message;
    private Integer readerUserId;
    private String readerName;
    private LocalDateTime readAt;
}
