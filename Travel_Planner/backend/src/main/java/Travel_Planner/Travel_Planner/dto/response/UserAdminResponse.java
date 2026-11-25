package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserAdminResponse {
    private Integer userId;
    private String username;
    private String handle;
    private String email;
    private String fullName;
    private String avatar;
    private Role role;
    private UserStatus status;
    private Boolean emailVerified;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static UserAdminResponse from(User user) {
        return UserAdminResponse.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .handle(user.getHandle())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .avatar(user.getAvatar())
                .role(user.getRole())
                .status(user.getStatus())
                .emailVerified(user.getEmailVerified())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .build();
    }
}
