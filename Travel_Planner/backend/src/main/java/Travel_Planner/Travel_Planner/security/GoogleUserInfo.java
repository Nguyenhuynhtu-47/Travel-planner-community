package Travel_Planner.Travel_Planner.security;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GoogleUserInfo {
    private String sub;
    private String email;
    private boolean emailVerified;
    private String name;
    private String picture;
}
