package Travel_Planner.Travel_Planner.dto.request;

import Travel_Planner.Travel_Planner.model.enums.Role;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class UpdateUserRoleRequest {

    @NotNull(message = "Vai trò mới không được để trống")
    private Role role;

    @NotBlank(message = "Lý do thay đổi vai trò không được để trống")
    @Size(min = 3, max = 255, message = "Lý do thay đổi vai trò phải từ 3 đến 255 ký tự")
    private String reason;
}
