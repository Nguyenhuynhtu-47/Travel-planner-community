package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.service.EmailService;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

@Service
public class EmailServiceImpl implements EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailServiceImpl.class);

    private final JavaMailSender mailSender;
    private final TemplateEngine templateEngine;

    @Value("${app.mail.enabled:false}")
    private boolean mailEnabled;

    @Value("${spring.mail.from:no-reply@travelplanner.local}")
    private String fromEmail;

    @Value("${spring.mail.username:}")
    private String mailUsername;

    @Autowired
    public EmailServiceImpl(@Autowired(required = false) JavaMailSender mailSender,
                            @Autowired(required = false) TemplateEngine templateEngine) {
        this.mailSender = mailSender;
        this.templateEngine = templateEngine;
    }

    private String getEffectiveFrom() {
        if (fromEmail != null && !fromEmail.isBlank() && !fromEmail.endsWith(".local")) {
            return fromEmail;
        }
        if (mailUsername != null && !mailUsername.isBlank()) {
            return mailUsername;
        }
        return (fromEmail != null && !fromEmail.isBlank()) ? fromEmail : "no-reply@travelplanner.local";
    }

    @Autowired(required = false)
    private org.springframework.core.env.Environment environment;

    @jakarta.annotation.PostConstruct
    public void validateMailConfigForProduction() {
        if (environment != null && java.util.Arrays.asList(environment.getActiveProfiles()).contains("prod")) {
            if (!mailEnabled) {
                log.warn("CRITICAL WARNING: 'prod' profile is active but app.mail.enabled is false! Email delivery is running in SIMULATION mode.");
            }
        }
    }

    @Override
    public void sendVerificationEmail(String toEmail, String fullName, String otp, int expirationMinutes) {
        if (!mailEnabled || mailSender == null) {
            log.info("--- [EmailService] Mail disabled (app.mail.enabled=false) or sender unavailable. Simulating verification email to {} (valid for {} mins). To send real emails, configure SMTP and set APP_MAIL_ENABLED=true ---",
                    maskEmail(toEmail), expirationMinutes);
            return;
        }

        try {
            log.info("--- [EmailService] Preparing verification email dispatch to {} ---", maskEmail(toEmail));
            String recipientName = (fullName != null && !fullName.trim().isEmpty()) ? fullName.trim() : "Quý khách";
            String htmlContent;

            if (templateEngine != null) {
                Context context = new Context();
                context.setVariable("fullName", recipientName);
                context.setVariable("otp", otp);
                context.setVariable("expirationMinutes", expirationMinutes);
                htmlContent = templateEngine.process("mail/email-verification", context);
            } else {
                htmlContent = "<p>Xin chào " + recipientName + ",</p><p>Mã xác thực Travel Planner của bạn là: <strong>"
                        + otp + "</strong> (hiệu lực " + expirationMinutes + " phút).</p>";
            }

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            String effectiveFrom = getEffectiveFrom();
            helper.setFrom(effectiveFrom, "Travel Planner Community");
            helper.setTo(toEmail);
            helper.setSubject("Mã xác thực tài khoản Travel Planner");
            helper.setText(htmlContent, true);

            mailSender.send(message);
            log.info("--- [EmailService] SMTP dispatch succeeded for verification email to {} ---", maskEmail(toEmail));
        } catch (Exception e) {
            log.error("--- [EmailService] SMTP dispatch failed for verification email to {}: {} ---", maskEmail(toEmail), e.getMessage(), e);
        }
    }

    @Override
    public void sendPasswordResetEmail(String toEmail, String fullName, String otp, int expirationMinutes) {
        if (!mailEnabled || mailSender == null) {
            log.info("--- [EmailService] Mail disabled (app.mail.enabled=false) or sender unavailable. Simulating password reset email to {} (valid for {} mins). To send real emails, configure SMTP and set APP_MAIL_ENABLED=true ---",
                    maskEmail(toEmail), expirationMinutes);
            return;
        }

        try {
            log.info("--- [EmailService] Preparing password reset email dispatch to {} ---", maskEmail(toEmail));
            String recipientName = (fullName != null && !fullName.trim().isEmpty()) ? fullName.trim() : "Quý khách";
            String htmlContent;

            if (templateEngine != null) {
                Context context = new Context();
                context.setVariable("fullName", recipientName);
                context.setVariable("otp", otp);
                context.setVariable("expirationMinutes", expirationMinutes);
                htmlContent = templateEngine.process("mail/password-reset", context);
            } else {
                htmlContent = "<p>Xin chào " + recipientName + ",</p><p>Mã đặt lại mật khẩu Travel Planner của bạn là: <strong>"
                        + otp + "</strong> (hiệu lực " + expirationMinutes + " phút).</p>"
                        + "<p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này hoặc liên hệ hỗ trợ để bảo vệ tài khoản.</p>";
            }

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            String effectiveFrom = getEffectiveFrom();
            helper.setFrom(effectiveFrom, "Travel Planner Community");
            helper.setTo(toEmail);
            helper.setSubject("Mã đặt lại mật khẩu Travel Planner");
            helper.setText(htmlContent, true);

            mailSender.send(message);
            log.info("--- [EmailService] SMTP dispatch succeeded for password reset email to {} ---", maskEmail(toEmail));
        } catch (Exception e) {
            log.error("--- [EmailService] SMTP dispatch failed for password reset email to {}: {} ---", maskEmail(toEmail), e.getMessage(), e);
        }
    }

    @Override
    public void sendEmailChangeOtp(String toNewEmail, String fullName, String otp, int expirationMinutes) {
        if (!mailEnabled || mailSender == null) {
            log.info("--- [EmailService] Mail disabled (app.mail.enabled=false). Simulating email change OTP to {} (valid for {} mins) ---",
                    maskEmail(toNewEmail), expirationMinutes);
            return;
        }

        try {
            log.info("--- [EmailService] Preparing email change OTP dispatch to {} ---", maskEmail(toNewEmail));
            String recipientName = (fullName != null && !fullName.trim().isEmpty()) ? fullName.trim() : "Quý khách";
            String htmlContent = "<p>Xin chào " + recipientName + ",</p><p>Mã xác thực để đổi địa chỉ email tài khoản Travel Planner của bạn là: <strong>"
                    + otp + "</strong> (hiệu lực " + expirationMinutes + " phút).</p>"
                    + "<p>Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email hoặc liên hệ với đội ngũ hỗ trợ.</p>";

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            String effectiveFrom = getEffectiveFrom();
            helper.setFrom(effectiveFrom, "Travel Planner Community");
            helper.setTo(toNewEmail);
            helper.setSubject("Mã xác thực đổi địa chỉ email - Travel Planner");
            helper.setText(htmlContent, true);

            mailSender.send(message);
            log.info("--- [EmailService] SMTP dispatch succeeded for email change OTP to {} ---", maskEmail(toNewEmail));
        } catch (Exception e) {
            log.error("--- [EmailService] SMTP dispatch failed for email change OTP to {}: {} ---", maskEmail(toNewEmail), e.getMessage(), e);
        }
    }

    @Override
    public void sendEmailChangeNotice(String toOldEmail, String fullName, String newEmail) {
        if (!mailEnabled || mailSender == null) {
            log.info("--- [EmailService] Mail disabled. Simulating email change security notice to old email {} (new: {}) ---",
                    maskEmail(toOldEmail), maskEmail(newEmail));
            return;
        }

        try {
            String recipientName = (fullName != null && !fullName.trim().isEmpty()) ? fullName.trim() : "Quý khách";
            String htmlContent = "<p>Xin chào " + recipientName + ",</p><p>Chúng tôi vừa nhận được yêu cầu đổi địa chỉ email tài khoản Travel Planner của bạn sang: <strong>"
                    + maskEmail(newEmail) + "</strong>.</p>"
                    + "<p>Nếu bạn không thực hiện yêu cầu này, tài khoản của bạn có thể đang bị truy cập trái phép. Vui lòng đăng nhập và đổi mật khẩu ngay lập tức.</p>";

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(getEffectiveFrom(), "Travel Planner Community");
            helper.setTo(toOldEmail);
            helper.setSubject("Cảnh báo bảo mật: Yêu cầu đổi địa chỉ email tài khoản Travel Planner");
            helper.setText(htmlContent, true);

            mailSender.send(message);
        } catch (Exception e) {
            log.error("--- [EmailService] SMTP notice failed to {}: {} ---", maskEmail(toOldEmail), e.getMessage());
        }
    }

    @Override
    public void sendEmailChangeSuccessNotice(String toOldEmail, String toNewEmail, String fullName) {
        if (!mailEnabled || mailSender == null) {
            log.info("--- [EmailService] Mail disabled. Simulating email change success notice to old: {}, new: {} ---",
                    maskEmail(toOldEmail), maskEmail(toNewEmail));
            return;
        }

        try {
            String recipientName = (fullName != null && !fullName.trim().isEmpty()) ? fullName.trim() : "Quý khách";
            String htmlContent = "<p>Xin chào " + recipientName + ",</p><p>Địa chỉ email tài khoản Travel Planner của bạn đã được thay đổi thành công thành: <strong>"
                    + toNewEmail + "</strong>.</p>";

            MimeMessage message1 = mailSender.createMimeMessage();
            MimeMessageHelper helper1 = new MimeMessageHelper(message1, true, "UTF-8");
            helper1.setFrom(getEffectiveFrom(), "Travel Planner Community");
            helper1.setTo(toOldEmail);
            helper1.setSubject("Thông báo: Địa chỉ email tài khoản Travel Planner đã thay đổi");
            helper1.setText(htmlContent, true);
            mailSender.send(message1);

            MimeMessage message2 = mailSender.createMimeMessage();
            MimeMessageHelper helper2 = new MimeMessageHelper(message2, true, "UTF-8");
            helper2.setFrom(getEffectiveFrom(), "Travel Planner Community");
            helper2.setTo(toNewEmail);
            helper2.setSubject("Chào mừng: Địa chỉ email mới của tài khoản Travel Planner");
            helper2.setText(htmlContent, true);
            mailSender.send(message2);
        } catch (Exception e) {
            log.error("--- [EmailService] SMTP success notice failed: {} ---", e.getMessage());
        }
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "***";
        int atIndex = email.indexOf('@');
        if (atIndex <= 2) return "***" + email.substring(atIndex);
        return email.substring(0, 2) + "***" + email.substring(atIndex);
    }
}
