package Travel_Planner.Travel_Planner.event;

import lombok.Getter;
import org.springframework.context.ApplicationEvent;

import java.time.LocalDateTime;

@Getter
public class UserVerificationEvent extends ApplicationEvent {

    private final Integer userId;
    private final String email;
    private final String fullName;
    private final String otp;
    private final LocalDateTime expiresAt;
    private final int expirationMinutes;

    public UserVerificationEvent(Object source, Integer userId, String email, String fullName,
                                 String otp, LocalDateTime expiresAt, int expirationMinutes) {
        super(source);
        this.userId = userId;
        this.email = email;
        this.fullName = fullName;
        this.otp = otp;
        this.expiresAt = expiresAt;
        this.expirationMinutes = expirationMinutes;
    }
}
