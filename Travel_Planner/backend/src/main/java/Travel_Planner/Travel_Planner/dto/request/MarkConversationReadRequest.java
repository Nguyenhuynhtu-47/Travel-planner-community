package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter @NoArgsConstructor
public class MarkConversationReadRequest {
    @NotNull @PositiveOrZero
    private Long lastReadSequence;
}
