package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.DecimalMax;
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

    @Size(max = 150, message = "Tên địa điểm tùy chỉnh tối đa 150 ký tự")
    private String customLocationName;

    @Size(max = 255, message = "Địa chỉ tùy chỉnh tối đa 255 ký tự")
    private String customAddress;

    @DecimalMin(value = "-90.0", message = "Tọa độ vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0")
    @DecimalMax(value = "90.0", message = "Tọa độ vĩ độ (latitude) phải nằm trong khoảng từ -90.0 đến 90.0")
    private BigDecimal latitude;

    @DecimalMin(value = "-180.0", message = "Tọa độ kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0")
    @DecimalMax(value = "180.0", message = "Tọa độ kinh độ (longitude) phải nằm trong khoảng từ -180.0 đến 180.0")
    private BigDecimal longitude;

    @Size(max = 100, message = "Mã địa điểm (placeId) tối đa 100 ký tự")
    private String placeId;

    @Size(max = 30, message = "Nhà cung cấp vị trí tối đa 30 ký tự")
    private String locationProvider;

    private LocalTime startTime;

    private LocalTime endTime;

    @DecimalMin(value = "0.0", message = "Chi phí không được âm")
    private BigDecimal cost;
}
