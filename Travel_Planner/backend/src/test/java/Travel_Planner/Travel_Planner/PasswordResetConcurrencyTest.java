package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.ResetPasswordRequest;
import Travel_Planner.Travel_Planner.dto.response.ResetPasswordResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.model.PasswordResetToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.PasswordResetTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.PasswordResetService;
import Travel_Planner.Travel_Planner.service.impl.PasswordResetServiceImpl;
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
import java.util.Optional;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class PasswordResetConcurrencyTest {

    @Autowired
    private PasswordResetService passwordResetService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordResetTokenRepository tokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Value("${auth.password-reset.pepper:test-travel-planner-pwd-reset-hmac-secret-pepper-2026}")
    private String pepper;

    private static final String TEST_EMAIL_PREFIX = "pwd_concurrency_";

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
            jdbcTemplate.execute("DELETE FROM password_reset_tokens WHERE user_id IN (SELECT user_id FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%')");
            jdbcTemplate.execute("DELETE FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%'");
        } catch (Exception e) {
            // ignore if empty
        }
    }

    private User createTestUser(String email, String username) {
        User user = User.builder()
                .username(username)
                .email(email)
                .handle(username)
                .password(passwordEncoder.encode("InitialPassword@123"))
                .fullName("Password Reset Concurrency User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        return userRepository.save(user);
    }

    @Test
    @DisplayName("Concurrency: 10 threads submit same reset OTP -> Exactly 1 succeeds, 9 fail, token deleted, token_version incremented")
    void testConcurrentReset_onlyOneSucceeds() throws InterruptedException {
        String email = TEST_EMAIL_PREFIX + "reset@example.com";
        User user = createTestUser(email, "concurrent_reset_user");

        String rawOtp = "889900";
        String tokenHash = PasswordResetServiceImpl.hashOtp(rawOtp, pepper);

        PasswordResetToken token = PasswordResetToken.builder()
                .user(user)
                .tokenHash(tokenHash)
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

        String newPassword = "BrandNewPassword@2026";

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    ResetPasswordRequest request = new ResetPasswordRequest(email, rawOtp, newPassword, newPassword);
                    ResetPasswordResponse response = passwordResetService.resetPassword(request);
                    if (response != null && response.getMessage() != null) {
                        successCount.incrementAndGet();
                    }
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

        assertTrue(finished, "All threads must finish within 10 seconds");
        assertEquals(1, successCount.get(), "Exactly 1 thread must succeed in resetting the password");
        assertEquals(threadCount - 1, failureCount.get(), "All other threads must fail");

        // Verify database state: password changed and token_version incremented
        User updatedUser = userRepository.findByEmail(email).orElseThrow();
        assertTrue(passwordEncoder.matches(newPassword, updatedUser.getPassword()), "User password must match new password");
        assertEquals(2, updatedUser.getTokenVersion(), "User token_version must be incremented from 1 to 2");

        // Verify token deleted
        Optional<PasswordResetToken> remainingToken = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(updatedUser.getUserId());
        assertTrue(remainingToken.isEmpty(), "Reset token must be deleted after consumption");
    }

    @Test
    @DisplayName("Concurrency: 5 threads with attempts=4 submit wrong OTP -> Token burned immediately, password and token_version unaltered")
    void testConcurrentWrongOtp_burnsToken() throws InterruptedException {
        String email = TEST_EMAIL_PREFIX + "burn@example.com";
        User user = createTestUser(email, "concurrent_burn_user");

        String validOtp = "123456";
        String tokenHash = PasswordResetServiceImpl.hashOtp(validOtp, pepper);

        PasswordResetToken token = PasswordResetToken.builder()
                .user(user)
                .tokenHash(tokenHash)
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
                    ResetPasswordRequest request = new ResetPasswordRequest(email, "000000", "NewValidPassword@123", "NewValidPassword@123");
                    passwordResetService.resetPassword(request);
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

        // Password and token_version must remain unaltered
        User updatedUser = userRepository.findByEmail(email).orElseThrow();
        assertTrue(passwordEncoder.matches("InitialPassword@123", updatedUser.getPassword()));
        assertEquals(1, updatedUser.getTokenVersion());

        // Token must be burned (deleted)
        Optional<PasswordResetToken> remainingToken = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(updatedUser.getUserId());
        assertTrue(remainingToken.isEmpty(), "Token must be burned and removed from database");
    }
}
