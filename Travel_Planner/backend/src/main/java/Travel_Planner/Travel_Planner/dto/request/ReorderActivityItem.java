package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
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
public class ReorderActivityItem {

    @NotNull(message = "Mã hoạt động không được để trống")
    private Integer activityId;

    @NotNull(message = "Thứ tự hiển thị không được để trống")
    @Min(value = 1, message = "Thứ tự hiển thị phải lớn hơn hoặc bằng 1")
    private Integer displayOrder;
}
