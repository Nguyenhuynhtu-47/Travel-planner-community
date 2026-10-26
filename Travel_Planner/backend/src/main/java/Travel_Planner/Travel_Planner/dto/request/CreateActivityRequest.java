package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateActivityRequest {

    @NotBlank(message = "Tên hoạt động không được để trống")
    @Size(max = 150, message = "Tên hoạt động tối đa 150 ký tự")
    private String name;

    private String description;

    private Integer destinationId;

    private LocalTime startTime;

    private LocalTime endTime;

    @DecimalMin(value = "0.0", message = "Chi phí không được âm")
    private BigDecimal cost;
}
