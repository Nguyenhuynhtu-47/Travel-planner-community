package Travel_Planner.Travel_Planner;

import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mail.javamail.MimeMessageHelper;

import java.util.Properties;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

/**
 * Manual SMTP Smoke Test for verifying live SMTP delivery (Gmail, MailHog, Brevo, SendGrid, etc.).
 *
 * Usage:
 * Set environment variables:
 *   SPRING_MAIL_HOST=smtp.gmail.com
 *   SPRING_MAIL_PORT=587
 *   SPRING_MAIL_USERNAME=your_email@gmail.com
 *   SPRING_MAIL_PASSWORD=your_16_char_app_password
 *   TEST_RECIPIENT_EMAIL=your_email@gmail.com
 *
 * Run manually via Maven:
 *   .\mvnw.cmd test -Dtest=ManualSmtpSmokeTest
 */
public class ManualSmtpSmokeTest {

    @Test
    @DisplayName("Manual SMTP Live Dispatch Smoke Test")
    void sendSmokeEmail() {
        String host = System.getenv("SPRING_MAIL_HOST");
        String portStr = System.getenv("SPRING_MAIL_PORT");
        String username = System.getenv("SPRING_MAIL_USERNAME");
        String password = System.getenv("SPRING_MAIL_PASSWORD");
        String recipient = System.getenv("TEST_RECIPIENT_EMAIL");

        if (host == null || username == null || password == null || recipient == null) {
            System.out.println("=== [ManualSmtpSmokeTest] SKIPPED: Missing environment variables (SPRING_MAIL_HOST, SPRING_MAIL_USERNAME, SPRING_MAIL_PASSWORD, TEST_RECIPIENT_EMAIL). ===");
            return;
        }

        int port = (portStr != null && !portStr.isBlank()) ? Integer.parseInt(portStr) : 587;

        JavaMailSenderImpl mailSender = new JavaMailSenderImpl();
        mailSender.setHost(host);
        mailSender.setPort(port);
        mailSender.setUsername(username);
        mailSender.setPassword(password);

        Properties props = mailSender.getJavaMailProperties();
        props.put("mail.transport.protocol", "smtp");
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.starttls.required", "true");
        props.put("mail.smtp.ssl.trust", host);
        props.put("mail.smtp.connectiontimeout", "5000");
        props.put("mail.smtp.timeout", "5000");
        props.put("mail.smtp.writetimeout", "5000");

        assertDoesNotThrow(() -> {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(username, "Travel Planner Smoke Test");
            helper.setTo(recipient);
            helper.setSubject("Travel Planner - SMTP Smoke Test Verification");
            helper.setText("<h3>Travel Planner SMTP Smoke Test</h3><p>Your SMTP delivery pipeline is working properly!</p>", true);

            mailSender.send(message);
            System.out.println("=== [ManualSmtpSmokeTest] SUCCESS: Email dispatched to " + recipient + " via " + host + ":" + port + " ===");
        });
    }
}
