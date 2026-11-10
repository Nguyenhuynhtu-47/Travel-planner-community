package Travel_Planner.Travel_Planner.dto.response;

import lombok.*;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class PublicUserSummaryResponse {
    private Integer userId;
    private String handle;
    private String username;
    private String fullName;
    private String avatar;
}
