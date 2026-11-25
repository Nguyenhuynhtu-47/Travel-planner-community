package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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
public class UpdateSystemSettingRequest {

    @NotBlank(message = "Giá trị cấu hình không được để trống.")
    @Size(max = 500, message = "Giá trị cấu hình tối đa 500 ký tự.")
    private String settingValue;

    @Size(max = 255, message = "Lý do thay đổi tối đa 255 ký tự.")
    private String reason;
}
