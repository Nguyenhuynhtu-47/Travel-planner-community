package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter @NoArgsConstructor
public class OpenConversationRequest {
    @NotNull @Positive
    private Integer recipientUserId;
}
