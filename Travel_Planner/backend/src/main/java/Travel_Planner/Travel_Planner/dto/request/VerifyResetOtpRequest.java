package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.*;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VerifyResetOtpRequest {

    @NotBlank(message = "Email không được để trống")
    @Email(message = "Email không đúng định dạng")
    private String email;

    @NotBlank(message = "Mã xác thực không được để trống")
    @Pattern(regexp = "^[0-9]{6}$", message = "Mã xác thực phải gồm 6 chữ số")
    private String otp;
}
