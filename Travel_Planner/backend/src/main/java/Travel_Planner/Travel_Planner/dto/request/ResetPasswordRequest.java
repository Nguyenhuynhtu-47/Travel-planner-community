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
public class ResetPasswordRequest {

    @NotBlank(message = "Email không được để trống")
    @Email(message = "Email không đúng định dạng")
    private String email;

    @Pattern(regexp = "^$|^[0-9]{6}$", message = "Mã xác thực phải gồm 6 chữ số")
    private String otp;

    private String resetToken;

    @NotBlank(message = "Mật khẩu mới không được để trống")
    private String newPassword;

    private String confirmPassword;

    public ResetPasswordRequest(String email, String otp, String newPassword, String confirmPassword) {
        this.email = email;
        this.otp = otp;
        this.resetToken = null;
        this.newPassword = newPassword;
        this.confirmPassword = confirmPassword;
    }
}
