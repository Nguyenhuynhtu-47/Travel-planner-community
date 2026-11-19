package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.ResendVerificationRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.ResendVerificationResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.model.EmailVerificationToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.EmailVerificationTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.EmailVerificationService;
import Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class EmailVerificationConcurrencyTest {

    @Autowired
    private EmailVerificationService emailVerificationService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EmailVerificationTokenRepository tokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Value("${auth.otp.pepper:test-travel-planner-otp-hmac-secret-pepper-2026}")
    private String pepper;

    private static final String TEST_EMAIL_PREFIX = "concurrency_";

    @BeforeEach
    void setUp() {
        cleanupTestData();
    }

    @AfterEach
    void tearDown() {
        cleanupTestData();
    }

    private void cleanupTestData() {
        try {
            jdbcTemplate.execute("DELETE FROM email_verification_tokens WHERE user_id IN (SELECT user_id FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%')");
            jdbcTemplate.execute("DELETE FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%'");
        } catch (Exception e) {
            // ignore if empty
        }
    }

    private User createTestUser(String email, String username, boolean emailVerified) {
        User user = User.builder()
                .username(username)
                .email(email)
                .handle(username)
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Concurrency Test User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(emailVerified)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .build();
        return userRepository.save(user);
    }

    @Test
    @DisplayName("Concurrency: 10 threads verify same OTP simultaneously -> Exactly 1 succeeds, 9 fail, token deleted, user verified")
    void testConcurrentVerification_onlyOneSucceeds() throws InterruptedException {
        String email = TEST_EMAIL_PREFIX + "verify@example.com";
        User user = createTestUser(email, "concurrent_user_verify", false);

        String rawOtp = "654321";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(rawOtp, pepper);

        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        int threadCount = 10;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);

        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);
        List<String> failureReasons = new CopyOnWriteArrayList<>();

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    VerifyEmailRequest request = new VerifyEmailRequest(email, rawOtp);
                    AuthResponse response = emailVerificationService.verifyEmail(request);
                    if (response != null && response.getToken() != null) {
                        successCount.incrementAndGet();
                    }
                } catch (Exception e) {
                    failureCount.incrementAndGet();
                    failureReasons.add(e.getClass().getSimpleName() + ": " + e.getMessage());
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        // Fire all threads simultaneously
        startLatch.countDown();
        boolean finished = doneLatch.await(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertTrue(finished, "All concurrent verification threads should finish within 10 seconds");
        assertEquals(1, successCount.get(), "Exactly 1 thread must succeed in verifying and activating the account");
        assertEquals(threadCount - 1, failureCount.get(), "All other threads must fail");

        // Verify database state: user is verified
        User updatedUser = userRepository.findByEmail(email).orElseThrow();
        assertTrue(updatedUser.getEmailVerified(), "User email_verified flag must be TRUE in database");

        // Verify database state: token is consumed/deleted
        Optional<EmailVerificationToken> remainingToken = tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(
                updatedUser.getUserId(), "EMAIL_VERIFICATION");
        assertTrue(remainingToken.isEmpty(), "Verification token must be deleted after activation");
    }

    @Test
    @DisplayName("Concurrency: 5 threads with attempts=4 submit wrong OTP -> Token burned, no attempt limit bypass, account stays unverified")
    void testConcurrentWrongOtp_burnsToken() throws InterruptedException {
        String email = TEST_EMAIL_PREFIX + "burn@example.com";
        User user = createTestUser(email, "concurrent_user_burn", false);

        String validOtp = "111222";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(validOtp, pepper);

        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(4) // 1 attempt remaining before burn
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        int threadCount = 5;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);

        AtomicInteger failureCount = new AtomicInteger(0);

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    VerifyEmailRequest request = new VerifyEmailRequest(email, "999999"); // Wrong OTP
                    emailVerificationService.verifyEmail(request);
                } catch (BadRequestException e) {
                    failureCount.incrementAndGet();
                } catch (Exception e) {
                    failureCount.incrementAndGet();
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        startLatch.countDown();
        boolean finished = doneLatch.await(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertTrue(finished);
        assertEquals(threadCount, failureCount.get(), "All threads submitting wrong OTP must fail");

        // User must remain unverified
        User updatedUser = userRepository.findByEmail(email).orElseThrow();
        assertFalse(updatedUser.getEmailVerified(), "User must remain unverified");

        // Token must be burned (deleted)
        Optional<EmailVerificationToken> remainingToken = tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(
                updatedUser.getUserId(), "EMAIL_VERIFICATION");
        assertTrue(remainingToken.isEmpty(), "Token must be burned and removed from database");
    }

    @Test
    @DisplayName("Concurrency: 5 threads call resendVerification -> Exactly 1 succeeds, others throttled by 60s cooldown")
    void testConcurrentResend_enforcesCooldown() throws InterruptedException {
        String email = TEST_EMAIL_PREFIX + "resend@example.com";
        User user = createTestUser(email, "concurrent_user_resend", false);

        // Previous token created 120 seconds ago (cooldown expired)
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash("dummyhash")
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        token = tokenRepository.save(token);
        // Manually adjust createdAt to 120 seconds ago
        jdbcTemplate.update("UPDATE email_verification_tokens SET created_at = DATE_SUB(NOW(), INTERVAL 120 SECOND) WHERE token_id = ?", token.getTokenId());

        int threadCount = 5;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);

        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger throttledCount = new AtomicInteger(0);

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    ResendVerificationRequest request = new ResendVerificationRequest(email);
                    ResendVerificationResponse res = emailVerificationService.resendVerification(request);
                    if (res != null) {
                        successCount.incrementAndGet();
                    }
                } catch (RateLimitExceededException e) {
                    throttledCount.incrementAndGet();
                } catch (Exception e) {
                    // unexpected
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        startLatch.countDown();
        boolean finished = doneLatch.await(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertTrue(finished);
        assertEquals(1, successCount.get(), "Exactly 1 thread should succeed in resending OTP");
        assertEquals(threadCount - 1, throttledCount.get(), "Remaining threads must be blocked by 60s cooldown");

        // Exactly 1 active token should exist for user
        List<EmailVerificationToken> tokens = tokenRepository.findAll();
        long userTokensCount = tokens.stream().filter(t -> t.getUser().getUserId().equals(user.getUserId())).count();
        assertEquals(1, userTokensCount, "Exactly 1 active token must exist in the database for the user");
    }

    @Test
    @DisplayName("Expired OTP: Expired token cannot be verified and is deleted")
    void testExpiredOtp_cannotBeVerified() {
        String email = TEST_EMAIL_PREFIX + "expired@example.com";
        User user = createTestUser(email, "concurrent_user_expired", false);

        String rawOtp = "123123";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(rawOtp, pepper);

        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().minusMinutes(5)) // Expired 5 mins ago
                .build();
        tokenRepository.save(token);

        VerifyEmailRequest request = new VerifyEmailRequest(email, rawOtp);
        BadRequestException ex = assertThrows(BadRequestException.class, () -> emailVerificationService.verifyEmail(request));
        assertTrue(ex.getMessage().contains("hết hạn"), "Exception must mention expiration");

        // User must remain unverified
        User updatedUser = userRepository.findByEmail(email).orElseThrow();
        assertFalse(updatedUser.getEmailVerified());

        // Token must be deleted
        Optional<EmailVerificationToken> remaining = tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(
                updatedUser.getUserId(), "EMAIL_VERIFICATION");
        assertTrue(remaining.isEmpty());
    }
}
