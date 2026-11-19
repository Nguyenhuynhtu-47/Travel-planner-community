package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmailChangeRequestDto {

    @NotBlank(message = "Email mới không được để trống")
    @Email(message = "Định dạng email không hợp lệ")
    private String newEmail;

    private String password;
}
