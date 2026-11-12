package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreatePostReportRequest {
    @NotBlank(message = "Lý do báo cáo không được để trống")
    @Size(max = 50, message = "Lý do báo cáo tối đa 50 ký tự")
    private String reason;

    @Size(max = 1000, message = "Chi tiết báo cáo tối đa 1000 ký tự")
    private String details;
}

