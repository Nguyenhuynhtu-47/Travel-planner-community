package Travel_Planner.Travel_Planner.service;

public interface EmailService {
    void sendVerificationEmail(String toEmail, String fullName, String otp, int expirationMinutes);
    void sendPasswordResetEmail(String toEmail, String fullName, String otp, int expirationMinutes);
    void sendEmailChangeOtp(String toNewEmail, String fullName, String otp, int expirationMinutes);
    void sendEmailChangeNotice(String toOldEmail, String fullName, String newEmail);
    void sendEmailChangeSuccessNotice(String toOldEmail, String toNewEmail, String fullName);
}
