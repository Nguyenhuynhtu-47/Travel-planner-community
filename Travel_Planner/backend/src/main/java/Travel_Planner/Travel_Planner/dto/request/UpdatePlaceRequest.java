package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePlaceRequest {

    @NotBlank(message = "Tên địa điểm không được để trống")
    @Size(max = 150, message = "Tên địa điểm không được vượt quá 150 ký tự")
    private String name;

    @NotBlank(message = "Địa chỉ không được để trống")
    @Size(max = 255, message = "Địa chỉ không được vượt quá 255 ký tự")
    private String address;

    private String description;

    @Size(max = 500, message = "URL ảnh không được vượt quá 500 ký tự")
    private String imageUrl;

    @NotNull(message = "Vĩ độ không được để trống")
    @DecimalMin(value = "-90.0", message = "Vĩ độ tối thiểu là -90.0")
    @DecimalMax(value = "90.0", message = "Vĩ độ tối đa là 90.0")
    private BigDecimal latitude;

    @NotNull(message = "Kinh độ không được để trống")
    @DecimalMin(value = "-180.0", message = "Kinh độ tối thiểu là -180.0")
    @DecimalMax(value = "180.0", message = "Kinh độ tối đa là 180.0")
    private BigDecimal longitude;

    @NotNull(message = "Danh mục địa điểm không được để trống")
    private PlaceCategory category;

    @NotNull(message = "Trạng thái địa điểm không được để trống")
    private PlaceStatus status;
}

