package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.util.List;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class MessagePageResponse {
    private List<MessageResponse> content;
    private boolean hasMore;
    private Long nextBeforeSequence;
    private Long lastSequence;
    private Long peerReadSequence;
}
