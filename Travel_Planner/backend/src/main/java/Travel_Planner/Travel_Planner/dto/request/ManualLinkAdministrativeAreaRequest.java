package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ManualLinkAdministrativeAreaRequest {

    @NotBlank(message = "Mã đơn vị hành chính không được để trống")
    private String administrativeAreaCode;

    private String reason;
}

