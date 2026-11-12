package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ModeratePostRequest {
    @NotNull(message = "Trạng thái kiểm duyệt không được để trống")
    private PostStatus status;

    @Size(max = 255, message = "Lý do kiểm duyệt tối đa 255 ký tự")
    private String moderationReason;
}

