package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.PostVisibility;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePostRequest {
    @Size(max = 2000, message = "Nội dung bài viết tối đa 2000 ký tự")
    private String content;

    private PostVisibility visibility;
}

