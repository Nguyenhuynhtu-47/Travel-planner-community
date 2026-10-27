package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.Visibility;
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
public class UpdateItineraryRequest {

    @NotBlank(message = "Tiêu đề không được để trống")
    @Size(min = 3, max = 150, message = "Tiêu đề phải từ 3 đến 150 ký tự")
    private String title;

    private String description;

    @NotBlank(message = "Điểm đến không được để trống")
    @Size(max = 150, message = "Điểm đến tối đa 150 ký tự")
    private String location;

    @Size(max = 500, message = "Đường dẫn ảnh bìa tối đa 500 ký tự")
    private String coverImage;

    @NotNull(message = "Ngân sách không được để trống")
    @DecimalMin(value = "0.0", message = "Ngân sách không được âm")
    private BigDecimal budget;

    @Size(max = 100, message = "Chủ đề tối đa 100 ký tự")
    private String theme;

    private Visibility visibility;
}
