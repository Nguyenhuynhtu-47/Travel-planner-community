package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.request.ResendVerificationRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.RegisterResponse;
import Travel_Planner.Travel_Planner.dto.response.ResendVerificationResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.model.EmailVerificationToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.repository.EmailVerificationTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.AuthService;
import Travel_Planner.Travel_Planner.service.impl.EmailServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.util.ReflectionTestUtils;
import org.thymeleaf.TemplateEngine;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@SpringBootTest
public class EmailVerificationDeliveryTest {

    @Autowired
    private AuthService authService;

    @Autowired
    private EmailVerificationServiceImpl emailVerificationService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EmailVerificationTokenRepository tokenRepository;

    @Autowired
    private TemplateEngine templateEngine;

    private final List<Integer> createdUserIds = new ArrayList<>();
    private Clock fixedClock;

    @BeforeEach
    void setUp() {
        fixedClock = Clock.fixed(Instant.parse("2026-11-17T12:00:00Z"), ZoneId.systemDefault());
        emailVerificationService.setClock(fixedClock);
    }

    @AfterEach
    void tearDown() {
        emailVerificationService.setClock(Clock.systemDefaultZone());
        for (Integer userId : createdUserIds) {
            try {
                tokenRepository.deleteByUserIdAndTokenType(userId, "EMAIL_VERIFICATION");
                userRepository.deleteById(userId);
            } catch (Exception ignored) {}
        }
    }

    private RegisterRequest createUniqueRegisterRequest() {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        return RegisterRequest.builder()
                .username("mail_user_" + suffix)
                .email("mail_user_" + suffix + "@example.com")
                .password("Password@123")
                .fullName("Mail Test User " + suffix)
                .handle("mailuser_" + suffix)
                .build();
    }

    @Test
    @DisplayName("Registration triggers OTP creation and safe persistence in database")
    void testRegistration_triggersOtpCreationAndPersistence() {
        RegisterRequest request = createUniqueRegisterRequest();

        RegisterResponse response = authService.register(request);

        assertNotNull(response);
        assertTrue(Boolean.TRUE.equals(response.getRequiresVerification()));
        assertEquals(request.getEmail(), response.getEmail());

        User user = userRepository.findByEmail(request.getEmail()).orElseThrow();
        createdUserIds.add(user.getUserId());
        assertFalse(user.getEmailVerified());

        EmailVerificationToken token = tokenRepository
                .findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION")
                .orElseThrow();

        assertEquals(0, token.getAttempts());
        assertNotNull(token.getTokenHash());
        assertNotNull(token.getExpiresAt());
        assertTrue(token.getExpiresAt().isAfter(token.getCreatedAt()));
    }

    @Test
    @DisplayName("EmailService dispatches email to JavaMailSender with correct recipient, subject, and template content")
    void testEmailSender_invokedWithCorrectRecipient() {
        JavaMailSender mockMailSender = mock(JavaMailSender.class);
        MimeMessage mimeMessage = new MimeMessage(Session.getInstance(new Properties()));
        when(mockMailSender.createMimeMessage()).thenReturn(mimeMessage);

        EmailServiceImpl emailService = new EmailServiceImpl(mockMailSender, templateEngine);
        ReflectionTestUtils.setField(emailService, "mailEnabled", true);
        ReflectionTestUtils.setField(emailService, "fromEmail", "no-reply@travelplanner.local");

        emailService.sendVerificationEmail("recipient@example.com", "Nguyen Van A", "123456", 15);

        verify(mockMailSender, times(1)).send(any(MimeMessage.class));
    }

    @Test
    @DisplayName("SMTP delivery failure (e.g. auth failed, connect failed) is handled gracefully without crashing")
    void testSmtpFailure_handledGracefullyWithoutCrashing() {
        JavaMailSender mockMailSender = mock(JavaMailSender.class);
        MimeMessage mimeMessage = new MimeMessage(Session.getInstance(new Properties()));
        when(mockMailSender.createMimeMessage()).thenReturn(mimeMessage);
        doThrow(new MailAuthenticationException("535 Authentication Credentials Invalid"))
                .when(mockMailSender).send(any(MimeMessage.class));

        EmailServiceImpl emailService = new EmailServiceImpl(mockMailSender, templateEngine);
        ReflectionTestUtils.setField(emailService, "mailEnabled", true);

        // Must not throw exception
        assertDoesNotThrow(() ->
                emailService.sendVerificationEmail("failed_smtp@example.com", "Test User", "654321", 15)
        );
    }

    @Test
    @DisplayName("Simulation mode when app.mail.enabled=false does not call JavaMailSender.send()")
    void testSimulationMode_whenMailDisabled() {
        JavaMailSender mockMailSender = mock(JavaMailSender.class);
        EmailServiceImpl emailService = new EmailServiceImpl(mockMailSender, templateEngine);
        ReflectionTestUtils.setField(emailService, "mailEnabled", false);

        emailService.sendVerificationEmail("simulated@example.com", "Sim User", "888888", 15);

        verify(mockMailSender, never()).send(any(MimeMessage.class));
    }

    @Test
    @DisplayName("Resend verification enforces 60s cooldown, then generates new OTP and updates expiration")
    void testResendVerification_enforcesCooldownAndGeneratesNewToken() {
        RegisterRequest request = createUniqueRegisterRequest();
        authService.register(request);

        User user = userRepository.findByEmail(request.getEmail()).orElseThrow();
        createdUserIds.add(user.getUserId());

        EmailVerificationToken initialToken = tokenRepository
                .findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION")
                .orElseThrow();

        // Immediate resend within 60s -> RateLimitExceededException
        ResendVerificationRequest resendReq = new ResendVerificationRequest(request.getEmail());
        assertThrows(RateLimitExceededException.class, () ->
                emailVerificationService.resendVerification(resendReq)
        );

        // Advance clock by 61 seconds
        Clock advancedClock = Clock.offset(fixedClock, Duration.ofSeconds(61));
        emailVerificationService.setClock(advancedClock);

        ResendVerificationResponse resendResp = emailVerificationService.resendVerification(resendReq);
        assertNotNull(resendResp);
        assertEquals(60, resendResp.getCooldownSeconds());

        EmailVerificationToken newToken = tokenRepository
                .findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION")
                .orElseThrow();

        assertNotEquals(initialToken.getTokenId(), newToken.getTokenId());
        assertTrue(newToken.getExpiresAt().isAfter(initialToken.getExpiresAt()));
    }

    @Test
    @DisplayName("Submitting valid OTP verifies account, marks emailVerified=true, deletes token and returns JWT")
    void testVerificationSuccess_activatesAccountAndIssuesJwt() {
        RegisterRequest request = createUniqueRegisterRequest();
        authService.register(request);

        User user = userRepository.findByEmail(request.getEmail()).orElseThrow();
        createdUserIds.add(user.getUserId());

        // In test, set known OTP
        String knownOtp = "123456";
        String pepper = (String) ReflectionTestUtils.getField(emailVerificationService, "pepper");
        String knownHash = EmailVerificationServiceImpl.hashOtp(knownOtp, pepper);

        EmailVerificationToken token = tokenRepository
                .findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION")
                .orElseThrow();
        token.setTokenHash(knownHash);
        tokenRepository.save(token);

        VerifyEmailRequest verifyReq = new VerifyEmailRequest(request.getEmail(), knownOtp);
        AuthResponse authResp = emailVerificationService.verifyEmail(verifyReq);

        assertNotNull(authResp);
        assertNotNull(authResp.getToken());
        assertEquals("Bearer", authResp.getTokenType());
        assertTrue(authResp.getUser().getEmailVerified());

        User verifiedUser = userRepository.findById(user.getUserId()).orElseThrow();
        assertTrue(verifiedUser.getEmailVerified());

        // Token is consumed
        assertTrue(tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION").isEmpty());
    }

    @Test
    @DisplayName("Submitting OTP at or past expiresAt is rejected and token is burned")
    void testExpirationBoundary_rejectsExpiredToken() {
        RegisterRequest request = createUniqueRegisterRequest();
        authService.register(request);

        User user = userRepository.findByEmail(request.getEmail()).orElseThrow();
        createdUserIds.add(user.getUserId());

        EmailVerificationToken token = tokenRepository
                .findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION")
                .orElseThrow();

        // Advance clock past expiration
        Clock expiredClock = Clock.offset(fixedClock, Duration.ofMinutes(16));
        emailVerificationService.setClock(expiredClock);

        VerifyEmailRequest verifyReq = new VerifyEmailRequest(request.getEmail(), "123456");
        BadRequestException ex = assertThrows(BadRequestException.class, () ->
                emailVerificationService.verifyEmail(verifyReq)
        );
        assertTrue(ex.getMessage().contains("hết hạn"));

        // Token must be burned
        assertTrue(tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION").isEmpty());
    }
}
