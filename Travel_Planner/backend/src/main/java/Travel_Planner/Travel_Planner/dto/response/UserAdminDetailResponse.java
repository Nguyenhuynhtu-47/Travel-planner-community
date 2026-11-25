package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserAdminDetailResponse {
    private Integer userId;
    private String username;
    private String handle;
    private String email;
    private String fullName;
    private String avatar;
    private String phone;
    private String address;
    private String bio;
    private Role role;
    private UserStatus status;
    private Boolean emailVerified;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private long itineraryCount;
    private long postCount;
    private long activeSessionCount;
    private List<UserSessionResponse> sessions;
}
