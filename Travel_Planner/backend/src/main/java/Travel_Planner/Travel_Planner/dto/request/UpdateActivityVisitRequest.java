package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class UpdateActivityVisitRequest {
    @NotNull(message = "Trạng thái đã ghé là bắt buộc")
    private Boolean visited;
}
