package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class UpsertDeviceTokenRequest {
    @NotBlank(message = "FCM token là bắt buộc")
    @Size(max = 4096, message = "FCM token vượt quá độ dài cho phép")
    private String token;

    @NotBlank(message = "Nền tảng là bắt buộc")
    @Pattern(regexp = "ANDROID", message = "Hiện chỉ hỗ trợ Android")
    private String platform;
}
