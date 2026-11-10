package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotNull;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter @NoArgsConstructor
public class UpdateMessagingSettingsRequest {
    @NotNull
    private InboundMessagePolicy inboundPolicy;
}
