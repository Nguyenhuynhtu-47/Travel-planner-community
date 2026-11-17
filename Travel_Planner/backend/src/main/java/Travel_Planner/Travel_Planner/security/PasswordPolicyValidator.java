package Travel_Planner.Travel_Planner.security;

import Travel_Planner.Travel_Planner.exception.BadRequestException;

import java.util.regex.Pattern;

public final class PasswordPolicyValidator {

    private PasswordPolicyValidator() {}

    public static final String PASSWORD_POLICY_REGEX =
            "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&#^()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/]).{8,100}$";

    public static final String PASSWORD_POLICY_MESSAGE =
            "Mật khẩu phải từ 8 đến 100 ký tự, bao gồm ít nhất 1 chữ hoa, 1 chữ thường, 1 chữ số và 1 ký tự đặc biệt.";

    private static final Pattern PATTERN = Pattern.compile(PASSWORD_POLICY_REGEX);

    public static void validate(String password) {
        if (password == null || !PATTERN.matcher(password).matches()) {
            throw new BadRequestException(PASSWORD_POLICY_MESSAGE);
        }
    }

    public static boolean isValid(String password) {
        return password != null && PATTERN.matcher(password).matches();
    }

    public static void validateResetPassword(String password) {
        if (password == null || password.trim().isEmpty()) {
            throw new BadRequestException("Mật khẩu mới không được để trống.");
        }
        if (password.length() < 6 || password.length() > 100) {
            throw new BadRequestException("Mật khẩu mới phải từ 6 đến 100 ký tự.");
        }
    }
}
