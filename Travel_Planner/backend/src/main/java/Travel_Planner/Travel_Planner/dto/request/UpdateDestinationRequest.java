package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.math.BigDecimal;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateDestinationRequest {

    @NotBlank(message = "Tên điểm đến không được để trống")
    @Size(max = 150, message = "Tên điểm đến không được vượt quá 150 ký tự")
    private String name;

    @NotBlank(message = "Địa chỉ điểm đến không được để trống")
    @Size(max = 255, message = "Địa chỉ điểm đến không được vượt quá 255 ký tự")
    private String address;

    @Size(max = 2000, message = "Mô tả không được vượt quá 2000 ký tự")
    private String description;

    @Size(max = 500, message = "Đường dẫn ảnh không được vượt quá 500 ký tự")
    private String imageUrl;

    @DecimalMin(value = "-90.0", message = "Vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0")
    @DecimalMax(value = "90.0", message = "Vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0")
    private BigDecimal latitude;

    @DecimalMin(value = "-180.0", message = "Kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0")
    @DecimalMax(value = "180.0", message = "Kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0")
    private BigDecimal longitude;

    private DestinationStatus status;
}

