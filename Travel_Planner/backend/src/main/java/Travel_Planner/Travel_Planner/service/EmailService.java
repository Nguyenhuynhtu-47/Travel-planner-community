package Travel_Planner.Travel_Planner.service;

public interface EmailService {
    void sendVerificationEmail(String toEmail, String fullName, String otp, int expirationMinutes);
    void sendPasswordResetEmail(String toEmail, String fullName, String otp, int expirationMinutes);
}
