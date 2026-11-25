package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
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
public class ModerateItineraryRequest {

    @NotNull(message = "Trạng thái kiểm duyệt không được để trống")
    private ItineraryStatus status;

    @NotBlank(message = "Lý do kiểm duyệt không được để trống")
    @Size(min = 3, max = 255, message = "Lý do kiểm duyệt phải từ 3 đến 255 ký tự")
    private String reason;
}
