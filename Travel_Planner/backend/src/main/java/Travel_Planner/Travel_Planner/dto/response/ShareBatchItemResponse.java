package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShareBatchItemResponse {
    private Integer recipientUserId;
    private String recipientUsername;
    private String recipientFullName;
    private boolean success;
    private String errorMessage;
    private Long conversationId;
    private Long messageId;
    private Long sequenceNumber;
}
