package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PostAuthorResponse {
    private Integer userId;
    private String handle;
    private String username;
    private String fullName;
    private String avatar;
}

