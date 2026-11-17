package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ForgotPasswordResponse {

    private String message;
    private int cooldownSeconds;
}
