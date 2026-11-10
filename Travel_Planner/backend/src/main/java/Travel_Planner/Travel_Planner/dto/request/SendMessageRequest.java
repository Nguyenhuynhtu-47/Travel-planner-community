package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter @NoArgsConstructor
public class SendMessageRequest {
    @NotBlank
    @Pattern(regexp = "(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", message = "clientMessageId phải là UUID hợp lệ")
    private String clientMessageId;

    @NotBlank(message = "Tin nhắn không được để trống")
    @Size(max = 4000, message = "Tin nhắn không được vượt quá 4.000 ký tự")
    private String content;
}
