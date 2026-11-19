package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VerifyResetOtpResponse {

    private String message;
    private String resetToken;
}
