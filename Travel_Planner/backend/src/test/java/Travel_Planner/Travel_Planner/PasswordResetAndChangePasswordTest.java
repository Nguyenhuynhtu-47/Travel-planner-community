package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.ChangePasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.ForgotPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.ResetPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyResetOtpRequest;
import Travel_Planner.Travel_Planner.model.PasswordResetToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.PasswordResetTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.AuthRateLimiter;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.impl.PasswordResetServiceImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.Optional;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class PasswordResetAndChangePasswordTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordResetTokenRepository tokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private AuthRateLimiter authRateLimiter;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private Travel_Planner.Travel_Planner.service.impl.PasswordResetServiceImpl passwordResetService;

    @Autowired
    private Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl emailVerificationService;

    @Autowired
    private Travel_Planner.Travel_Planner.repository.EmailVerificationTokenRepository emailVerificationTokenRepository;

    @Value("${auth.password-reset.pepper:test-travel-planner-pwd-reset-hmac-secret-pepper-2026}")
    private String pepper;

    @Value("${auth.otp.pepper:travel-planner-otp-hmac-secret-pepper-2026}")
    private String emailPepper;

    @Value("${jwt.secret:404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970}")
    private String jwtSecret;

    private MockMvc mockMvc;
    private ObjectMapper objectMapper;

    private static final String TEST_EMAIL_PREFIX = "pwdtest_";

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders
                .webAppContextSetup(context)
                .apply(springSecurity())
                .build();
        objectMapper = new ObjectMapper();
        authRateLimiter.clear();
        passwordResetService.setClock(java.time.Clock.systemDefaultZone());
        emailVerificationService.setClock(java.time.Clock.systemDefaultZone());
        cleanupTestData();
    }

    @AfterEach
    void tearDown() {
        passwordResetService.setClock(java.time.Clock.systemDefaultZone());
        emailVerificationService.setClock(java.time.Clock.systemDefaultZone());
        cleanupTestData();
        authRateLimiter.clear();
    }

    private void cleanupTestData() {
        try {
            jdbcTemplate.execute("DELETE FROM email_verification_tokens WHERE user_id IN (SELECT user_id FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%')");
            jdbcTemplate.execute("DELETE FROM password_reset_tokens WHERE user_id IN (SELECT user_id FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%')");
            jdbcTemplate.execute("DELETE FROM users WHERE email LIKE '" + TEST_EMAIL_PREFIX + "%'");
        } catch (Exception e) {
            // ignore
        }
    }

    private User createTestUser(String email, String username, boolean verified, UserStatus status) {
        User user = User.builder()
                .username(username)
                .email(email)
                .handle(username)
                .password(passwordEncoder.encode("CurrentPassword@123"))
                .fullName("Test User " + username)
                .role(Role.USER)
                .status(status)
                .emailVerified(verified)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        return userRepository.save(user);
    }

    @Test
    @DisplayName("Forgot Password: Anti-enumeration generic response for existing, non-existing, unverified, and banned users")
    void testForgotPassword_antiEnumeration() throws Exception {
        // 1. Existing verified active user -> 200 generic message
        authRateLimiter.clear();
        String email1 = TEST_EMAIL_PREFIX + "existing@example.com";
        createTestUser(email1, "user_existing", true, UserStatus.ACTIVE);

        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email1))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("Nếu địa chỉ email tồn tại")))
                .andExpect(jsonPath("$.cooldownSeconds", is(60)));

        // Token should be created in DB
        User user1 = userRepository.findByEmail(email1).orElseThrow();
        Optional<PasswordResetToken> tokenOpt = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user1.getUserId());
        assertTrue(tokenOpt.isPresent(), "Token must be created for valid active verified user");

        // 2. Non-existing email -> 200 identical generic message
        authRateLimiter.clear();
        String email2 = TEST_EMAIL_PREFIX + "nonexisting@example.com";
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email2))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("Nếu địa chỉ email tồn tại")));

        // 3. Unverified email -> 200 identical generic message, but NO token created
        authRateLimiter.clear();
        String email3 = TEST_EMAIL_PREFIX + "unverified@example.com";
        createTestUser(email3, "user_unverified", false, UserStatus.ACTIVE);
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email3))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("Nếu địa chỉ email tồn tại")));

        User user3 = userRepository.findByEmail(email3).orElseThrow();
        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user3.getUserId()).isEmpty());

        // 4. Banned email -> 200 identical generic message, NO token created
        authRateLimiter.clear();
        String email4 = TEST_EMAIL_PREFIX + "banned@example.com";
        createTestUser(email4, "user_banned", true, UserStatus.BANNED);
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email4))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("Nếu địa chỉ email tồn tại")));

        User user4 = userRepository.findByEmail(email4).orElseThrow();
        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user4.getUserId()).isEmpty());
    }

    @Test
    @DisplayName("Forgot Password: Resend cooldown under 60s returns 429 with accurate Retry-After")
    void testForgotPassword_resendCooldown() throws Exception {
        String email = TEST_EMAIL_PREFIX + "cooldown@example.com";
        createTestUser(email, "user_cooldown", true, UserStatus.ACTIVE);

        // First request succeeds
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email))))
                .andExpect(status().isOk());

        // Second request immediately after -> 429 Too Many Requests with Retry-After header
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email))))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.message", containsString("Vui lòng đợi")));
    }

    @Test
    @DisplayName("Reset Password: Correct OTP resets password, increments token_version, and deletes token")
    void testResetPassword_success() throws Exception {
        String email = TEST_EMAIL_PREFIX + "reset_ok@example.com";
        User user = createTestUser(email, "user_reset_ok", true, UserStatus.ACTIVE);

        String rawOtp = "654321";
        String tokenHash = PasswordResetServiceImpl.hashOtp(rawOtp, pepper);
        PasswordResetToken token = PasswordResetToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        String newPassword = "BrandNewPassword@2026";
        ResetPasswordRequest request = new ResetPasswordRequest(email, rawOtp, newPassword, newPassword);

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("thành công")));

        // Verify database: password updated, token_version = 2, token deleted
        User updated = userRepository.findByEmail(email).orElseThrow();
        assertTrue(passwordEncoder.matches(newPassword, updated.getPassword()));
        assertEquals(2, updated.getTokenVersion());
        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId()).isEmpty());
    }

    @Test
    @DisplayName("Reset Password: Wrong OTP increments attempts, 5th attempt burns token")
    void testResetPassword_wrongOtpAndBurn() throws Exception {
        String email = TEST_EMAIL_PREFIX + "wrong_otp@example.com";
        User user = createTestUser(email, "user_wrong_otp", true, UserStatus.ACTIVE);

        String validOtp = "123456";
        String tokenHash = PasswordResetServiceImpl.hashOtp(validOtp, pepper);
        PasswordResetToken token = PasswordResetToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        ResetPasswordRequest request = new ResetPasswordRequest(email, "999999", "NewPassword@123", "NewPassword@123");

        // Attempt 1: 4 attempts remaining
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("Bạn còn 4 lần thử")));

        // Attempts 2, 3, 4
        for (int i = 2; i <= 4; i++) {
            mockMvc.perform(post("/api/auth/reset-password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isBadRequest());
        }

        // Attempt 5 -> Token burned!
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("quá số lần cho phép")));

        // Token must be burned (deleted)
        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId()).isEmpty());
    }

    @Test
    @DisplayName("Reset Password: Password policy enforcement and matching current password rejection")
    void testResetPassword_passwordPolicyAndSamePassword() throws Exception {
        String email = TEST_EMAIL_PREFIX + "policy@example.com";
        User user = createTestUser(email, "user_policy", true, UserStatus.ACTIVE);

        String rawOtp = "777888";
        String tokenHash = PasswordResetServiceImpl.hashOtp(rawOtp, pepper);
        tokenRepository.save(PasswordResetToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build());

        // 1. Password shorter than 6 characters -> 400
        ResetPasswordRequest shortReq = new ResetPasswordRequest(email, rawOtp, "short", "short");
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(shortReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("từ 6 đến 100 ký tự")));

        // 2. Same as current password -> 400
        ResetPasswordRequest sameReq = new ResetPasswordRequest(email, rawOtp, "CurrentPassword@123", "CurrentPassword@123");
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(sameReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("không được trùng")));

        // 3. Confirm password mismatch -> 400
        ResetPasswordRequest mismatchReq = new ResetPasswordRequest(email, rawOtp, "ValidNewPassword@123", "DifferentPassword@123");
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(mismatchReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("xác nhận không khớp")));
    }

    @Test
    @DisplayName("Change Password & JWT Revocation: Password change invalidates old token, new token works")
    void testChangePassword_jwtRevocation() throws Exception {
        String email = TEST_EMAIL_PREFIX + "change_pwd@example.com";
        User user = createTestUser(email, "user_change_pwd", true, UserStatus.ACTIVE);

        // Generate JWT_1 (holding tokenVersion = 1)
        String jwt1 = jwtTokenProvider.generateToken(user);

        // Verify JWT_1 works on /api/auth/me
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + jwt1))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("user_change_pwd")));

        // 1. Change password with wrong current password -> 401 BadCredentialsException
        ChangePasswordRequest wrongCurReq = new ChangePasswordRequest("WrongPassword@123", "ValidNewPwd@456", "ValidNewPwd@456");
        mockMvc.perform(post("/api/auth/change-password")
                        .header("Authorization", "Bearer " + jwt1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongCurReq)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message", containsString("Mật khẩu hiện tại không chính xác")));

        // Password and tokenVersion remain untouched
        User unchanged = userRepository.findByEmail(email).orElseThrow();
        assertEquals(1, unchanged.getTokenVersion());

        // 2. Change password with valid credentials -> 200 OK
        String newPassword = "NewValidSecretPassword@2026";
        ChangePasswordRequest validReq = new ChangePasswordRequest("CurrentPassword@123", newPassword, newPassword);
        mockMvc.perform(post("/api/auth/change-password")
                        .header("Authorization", "Bearer " + jwt1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("thành công")));

        // Database token_version is now 2
        User updated = userRepository.findByEmail(email).orElseThrow();
        assertEquals(2, updated.getTokenVersion());
        assertTrue(passwordEncoder.matches(newPassword, updated.getPassword()));

        // 3. Old JWT_1 must now be REJECTED (401 Unauthorized) because tokenVersion (1) < DB version (2)
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + jwt1))
                .andExpect(status().isUnauthorized());

        // 4. Log in with new password -> obtain JWT_2 (tokenVersion = 2)
        LoginRequest loginReq = new LoginRequest("user_change_pwd", newPassword);
        String loginResponseJson = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        String jwt2 = objectMapper.readTree(loginResponseJson).get("token").asText();

        // 5. JWT_2 must succeed on /api/auth/me
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + jwt2))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("user_change_pwd")));
    }

    @Test
    @DisplayName("JWT Revocation: Legacy token without tokenVersion claim is accepted when DB=1 and rejected when DB>1")
    void testLegacyTokenCompatibility() throws Exception {
        String email = TEST_EMAIL_PREFIX + "legacy@example.com";
        User user = createTestUser(email, "user_legacy", true, UserStatus.ACTIVE);

        // Craft a legacy JWT without "tokenVersion" claim
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        String legacyToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("userId", user.getUserId())
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name())
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        // When DB version is 1 -> legacy token is accepted
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + legacyToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("user_legacy")));

        // Increment DB version to 2 (simulating password change/revocation)
        user.setTokenVersion(2);
        userRepository.save(user);

        // Now legacy token without claim MUST be rejected (401)
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + legacyToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("JWT TokenVersion: Strict equality verification (matching, stale, future, missing, malformed, negative)")
    void testJwtTokenVersion_strictEqualityScenarios() throws Exception {
        String email = TEST_EMAIL_PREFIX + "strict_jwt@example.com";
        User user = createTestUser(email, "user_strict_jwt", true, UserStatus.ACTIVE);
        user.setTokenVersion(2);
        userRepository.save(user);

        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));

        // 1. Matching version (JWT=2, DB=2) -> 200 OK
        String matchingToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("tokenVersion", 2)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + matchingToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("user_strict_jwt")));

        // 2. Stale version (JWT=1, DB=2) -> 401 Unauthorized
        String staleToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("tokenVersion", 1)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + staleToken))
                .andExpect(status().isUnauthorized());

        // 3. Future version (JWT=3, DB=2) -> 401 Unauthorized
        String futureToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("tokenVersion", 3)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + futureToken))
                .andExpect(status().isUnauthorized());

        // 4. Missing claim with DB version 1 -> 200 OK
        user.setTokenVersion(1);
        userRepository.save(user);
        String missingClaimToken = Jwts.builder()
                .subject(user.getUsername())
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + missingClaimToken))
                .andExpect(status().isOk());

        // 5. Missing claim with DB version greater than 1 -> 401 Unauthorized
        user.setTokenVersion(2);
        userRepository.save(user);
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + missingClaimToken))
                .andExpect(status().isUnauthorized());

        // 6. Malformed claim (string "not_a_number") -> 401 Unauthorized
        String malformedToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("tokenVersion", "not_a_number")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + malformedToken))
                .andExpect(status().isUnauthorized());

        // 7. Negative claim (tokenVersion = -1 or 0) -> 401 Unauthorized
        String negativeToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("tokenVersion", -1)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + negativeToken))
                .andExpect(status().isUnauthorized());

        String zeroToken = Jwts.builder()
                .subject(user.getUsername())
                .claim("tokenVersion", 0)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + zeroToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Password Reset: Exact OTP Expiration Boundary Tests using Injectable Clock (now < expiresAt, now == expiresAt, now > expiresAt)")
    void testResetPassword_exactOtpExpirationBoundaryClock() throws Exception {
        java.time.Instant expiresInstant = java.time.Instant.parse("2026-11-17T12:00:00.000Z");
        java.time.ZoneId zone = java.time.ZoneId.systemDefault();
        LocalDateTime expiresAt = LocalDateTime.ofInstant(expiresInstant, zone);

        // --- Sub-case 1: now = expiresAt - 1 millis -> VALID (Token accepted) ---
        String email1 = TEST_EMAIL_PREFIX + "boundary_valid@example.com";
        User user1 = createTestUser(email1, "user_boundary_valid", true, UserStatus.ACTIVE);
        String rawOtp1 = "111222";
        tokenRepository.save(PasswordResetToken.builder()
                .user(user1)
                .tokenHash(PasswordResetServiceImpl.hashOtp(rawOtp1, pepper))
                .attempts(0)
                .expiresAt(expiresAt)
                .build());

        passwordResetService.setClock(java.time.Clock.fixed(expiresInstant.minusMillis(1), zone));

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ResetPasswordRequest(email1, rawOtp1, "ValidNewSecret@123", "ValidNewSecret@123"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("thành công")));

        // --- Sub-case 2: now = expiresAt (exact equality boundary) -> EXPIRED (Token rejected and consumed) ---
        String email2 = TEST_EMAIL_PREFIX + "boundary_exact@example.com";
        User user2 = createTestUser(email2, "user_boundary_exact", true, UserStatus.ACTIVE);
        String rawOtp2 = "333444";
        tokenRepository.save(PasswordResetToken.builder()
                .user(user2)
                .tokenHash(PasswordResetServiceImpl.hashOtp(rawOtp2, pepper))
                .attempts(0)
                .expiresAt(expiresAt)
                .build());

        passwordResetService.setClock(java.time.Clock.fixed(expiresInstant, zone));

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ResetPasswordRequest(email2, rawOtp2, "ValidNewSecret@123", "ValidNewSecret@123"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("hết hạn")));

        // Token must be consumed/deleted upon expiration check
        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user2.getUserId()).isEmpty(),
                "Expired token at exact boundary must be consumed and deleted from database");

        // Verify it cannot be reused
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ResetPasswordRequest(email2, rawOtp2, "ValidNewSecret@123", "ValidNewSecret@123"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("không tồn tại")));

        // --- Sub-case 3: now = expiresAt + 1 millis -> EXPIRED (Token rejected and consumed) ---
        String email3 = TEST_EMAIL_PREFIX + "boundary_after@example.com";
        User user3 = createTestUser(email3, "user_boundary_after", true, UserStatus.ACTIVE);
        String rawOtp3 = "555666";
        tokenRepository.save(PasswordResetToken.builder()
                .user(user3)
                .tokenHash(PasswordResetServiceImpl.hashOtp(rawOtp3, pepper))
                .attempts(0)
                .expiresAt(expiresAt)
                .build());

        passwordResetService.setClock(java.time.Clock.fixed(expiresInstant.plusMillis(1), zone));

        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ResetPasswordRequest(email3, rawOtp3, "ValidNewSecret@123", "ValidNewSecret@123"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("hết hạn")));

        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user3.getUserId()).isEmpty(),
                "Expired token after boundary must be consumed and deleted from database");
    }

    @Test
    @DisplayName("Email Verification: Exact OTP Expiration Boundary Tests using Injectable Clock (now < expiresAt, now == expiresAt, now > expiresAt)")
    void testEmailVerification_exactOtpExpirationBoundaryClock() throws Exception {
        java.time.Instant expiresInstant = java.time.Instant.parse("2026-11-17T12:00:00.000Z");
        java.time.ZoneId zone = java.time.ZoneId.systemDefault();
        LocalDateTime expiresAt = LocalDateTime.ofInstant(expiresInstant, zone);

        // --- Sub-case 1: now = expiresAt - 1 millis -> VALID (Account activated) ---
        String email1 = TEST_EMAIL_PREFIX + "evt_boundary_valid@example.com";
        User user1 = createTestUser(email1, "user_evt_valid", false, UserStatus.ACTIVE);
        String rawOtp1 = "123123";
        emailVerificationTokenRepository.save(Travel_Planner.Travel_Planner.model.EmailVerificationToken.builder()
                .user(user1)
                .tokenHash(Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl.hashOtp(rawOtp1, emailPepper))
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(expiresAt)
                .build());

        emailVerificationService.setClock(java.time.Clock.fixed(expiresInstant.minusMillis(1), zone));

        mockMvc.perform(post("/api/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest(email1, rawOtp1))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.emailVerified", is(true)));

        // --- Sub-case 2: now = expiresAt (exact boundary) -> EXPIRED (Rejected & consumed) ---
        String email2 = TEST_EMAIL_PREFIX + "evt_boundary_exact@example.com";
        User user2 = createTestUser(email2, "user_evt_exact", false, UserStatus.ACTIVE);
        String rawOtp2 = "456456";
        emailVerificationTokenRepository.save(Travel_Planner.Travel_Planner.model.EmailVerificationToken.builder()
                .user(user2)
                .tokenHash(Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl.hashOtp(rawOtp2, emailPepper))
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(expiresAt)
                .build());

        emailVerificationService.setClock(java.time.Clock.fixed(expiresInstant, zone));

        mockMvc.perform(post("/api/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest(email2, rawOtp2))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("hết hạn")));

        assertTrue(emailVerificationTokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user2.getUserId(), "EMAIL_VERIFICATION").isEmpty(),
                "Expired email verification token must be deleted upon expiration evaluation");

        // Verify account remained unverified
        User unchanged2 = userRepository.findByEmail(email2).orElseThrow();
        assertFalse(unchanged2.getEmailVerified());

        // --- Sub-case 3: now = expiresAt + 1 millis -> EXPIRED (Rejected & consumed) ---
        String email3 = TEST_EMAIL_PREFIX + "evt_boundary_after@example.com";
        User user3 = createTestUser(email3, "user_evt_after", false, UserStatus.ACTIVE);
        String rawOtp3 = "789789";
        emailVerificationTokenRepository.save(Travel_Planner.Travel_Planner.model.EmailVerificationToken.builder()
                .user(user3)
                .tokenHash(Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl.hashOtp(rawOtp3, emailPepper))
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(expiresAt)
                .build());

        emailVerificationService.setClock(java.time.Clock.fixed(expiresInstant.plusMillis(1), zone));

        mockMvc.perform(post("/api/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest(email3, rawOtp3))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("hết hạn")));

        assertTrue(emailVerificationTokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user3.getUserId(), "EMAIL_VERIFICATION").isEmpty());
    }

    @Test
    @DisplayName("P0 Migration Safety & Idempotency: Verifies legacy user migration procedures on disposable test tables and validates authentication")
    void testLegacyUserMigrationAndAuthentication() throws Exception {
        // Step 1: Create a disposable temporary table mimicking fresh legacy users table (no email_verified, no token_version)
        jdbcTemplate.execute("DROP TEMPORARY TABLE IF EXISTS temp_legacy_users");
        jdbcTemplate.execute("""
            CREATE TEMPORARY TABLE temp_legacy_users (
                user_id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) NOT NULL,
                email VARCHAR(100) NOT NULL,
                password VARCHAR(255) NOT NULL,
                status VARCHAR(20) NOT NULL
            )
        """);

        // Insert legacy user rows
        jdbcTemplate.execute("INSERT INTO temp_legacy_users (username, email, password, status) VALUES ('legacy_alice', 'alice@example.com', 'pwd_hash', 'ACTIVE')");
        jdbcTemplate.execute("INSERT INTO temp_legacy_users (username, email, password, status) VALUES ('legacy_bob', 'bob@example.com', 'pwd_hash', 'ACTIVE')");

        // Step 2: Apply Migration Procedure A (Fresh legacy database migration)
        jdbcTemplate.execute("ALTER TABLE temp_legacy_users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT TRUE");
        jdbcTemplate.execute("ALTER TABLE temp_legacy_users ALTER COLUMN email_verified SET DEFAULT FALSE");
        jdbcTemplate.execute("ALTER TABLE temp_legacy_users ADD COLUMN token_version INT NOT NULL DEFAULT 1");

        // Assert all legacy users are verified = TRUE and token_version = 1
        Integer aliceVerified = jdbcTemplate.queryForObject("SELECT email_verified FROM temp_legacy_users WHERE username = 'legacy_alice'", Integer.class);
        Integer bobVerified = jdbcTemplate.queryForObject("SELECT email_verified FROM temp_legacy_users WHERE username = 'legacy_bob'", Integer.class);
        Integer aliceTokenVer = jdbcTemplate.queryForObject("SELECT token_version FROM temp_legacy_users WHERE username = 'legacy_alice'", Integer.class);
        assertEquals(1, aliceVerified, "Legacy user Alice must be email_verified = TRUE");
        assertEquals(1, bobVerified, "Legacy user Bob must be email_verified = TRUE");
        assertEquals(1, aliceTokenVer, "Legacy user Alice must have token_version = 1");

        // Step 3: Insert a new user without specifying email_verified (simulating post-migration registration)
        jdbcTemplate.execute("INSERT INTO temp_legacy_users (username, email, password, status) VALUES ('new_user', 'new@example.com', 'pwd_hash', 'ACTIVE')");
        Integer newVerified = jdbcTemplate.queryForObject("SELECT email_verified FROM temp_legacy_users WHERE username = 'new_user'", Integer.class);
        assertEquals(0, newVerified, "New user registered after migration MUST default to email_verified = FALSE");

        // Step 4: Test Procedure B (Already-migrated database safety & idempotency)
        // Simulate a scenario where a legacy user accidentally had email_verified = FALSE during an initial faulty script,
        // while a new unverified user has a token in verification tokens table
        jdbcTemplate.execute("DROP TEMPORARY TABLE IF EXISTS temp_sim_tokens");
        jdbcTemplate.execute("""
            CREATE TEMPORARY TABLE temp_sim_tokens (
                token_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL
            )
        """);
        // new_user (user_id = 3) has an active verification token awaiting OTP
        jdbcTemplate.execute("INSERT INTO temp_sim_tokens (user_id) VALUES (3)");
        // legacy_bob (user_id = 2) was set to 0 by mistake
        jdbcTemplate.execute("UPDATE temp_legacy_users SET email_verified = 0 WHERE username = 'legacy_bob'");

        // Execute Procedure B query
        jdbcTemplate.execute("""
            UPDATE temp_legacy_users u
            LEFT JOIN temp_sim_tokens evt ON u.user_id = evt.user_id
            SET u.email_verified = TRUE
            WHERE evt.token_id IS NULL AND u.email_verified = FALSE
        """);

        Integer bobRestored = jdbcTemplate.queryForObject("SELECT email_verified FROM temp_legacy_users WHERE username = 'legacy_bob'", Integer.class);
        Integer newStillUnverified = jdbcTemplate.queryForObject("SELECT email_verified FROM temp_legacy_users WHERE username = 'new_user'", Integer.class);
        assertEquals(1, bobRestored, "Legacy Bob without token MUST be safely restored to email_verified = TRUE");
        assertEquals(0, newStillUnverified, "New unverified user with pending token MUST REMAIN email_verified = FALSE");

        // Clean up temporary tables
        jdbcTemplate.execute("DROP TEMPORARY TABLE IF EXISTS temp_sim_tokens");
        jdbcTemplate.execute("DROP TEMPORARY TABLE IF EXISTS temp_legacy_users");

        // Step 5: Verify that in the live application, a migrated legacy user can authenticate and access protected endpoints
        String legacyEmail = TEST_EMAIL_PREFIX + "auth_migrated_legacy@example.com";
        String rawPassword = "CurrentPassword@123";
        createTestUser(legacyEmail, "user_migrated_legacy", true, UserStatus.ACTIVE);

        // Authenticate via /api/auth/login
        String loginRes = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest("user_migrated_legacy", rawPassword))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        String jwt = objectMapper.readTree(loginRes).get("token").asText();
        assertNotNull(jwt, "Migrated legacy user must successfully receive a valid JWT token upon login");

        // Verify protected access via /api/auth/me
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("user_migrated_legacy")))
                .andExpect(jsonPath("$.emailVerified", is(true)));
    }

    @Test
    @DisplayName("3-Step Forgot Password Flow & Relaxed Password Policy Verification")
    void testThreeStepForgotPasswordFlow_andRelaxedPasswordPolicy() throws Exception {
        String email = TEST_EMAIL_PREFIX + "three_step@example.com";
        User user = createTestUser(email, "user_three_step", true, UserStatus.ACTIVE);

        // Step 1: Request OTP via forgot-password
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ForgotPasswordRequest(email))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("hộp thư của bạn")));

        // Retrieve OTP hash from database
        PasswordResetToken token = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId()).orElseThrow();
        assertNotNull(token);

        // For testing, let's create a known OTP
        String rawOtp = "123456";
        token.setTokenHash(PasswordResetServiceImpl.hashOtp(rawOtp, pepper));
        tokenRepository.save(token);

        // Step 2: Test wrong OTP -> 400
        VerifyResetOtpRequest wrongOtpReq = new VerifyResetOtpRequest(email, "999999");
        mockMvc.perform(post("/api/auth/verify-reset-otp")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongOtpReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("không chính xác")));

        // Step 2: Test valid OTP -> 200, returns resetToken
        VerifyResetOtpRequest validOtpReq = new VerifyResetOtpRequest(email, rawOtp);
        String verifyRes = mockMvc.perform(post("/api/auth/verify-reset-otp")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validOtpReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resetToken", notNullValue()))
                .andReturn().getResponse().getContentAsString();

        String resetToken = objectMapper.readTree(verifyRes).get("resetToken").asText();
        assertNotNull(resetToken);

        // Step 3 with relaxed password policy:
        // A. Password too short (< 6 chars) -> 400
        ResetPasswordRequest shortReq = ResetPasswordRequest.builder()
                .email(email)
                .resetToken(resetToken)
                .newPassword("12345")
                .confirmPassword("12345")
                .build();
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(shortReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("từ 6 đến 100 ký tự")));

        // B. Confirm password mismatch -> 400
        ResetPasswordRequest mismatchReq = ResetPasswordRequest.builder()
                .email(email)
                .resetToken(resetToken)
                .newPassword("onlylowercase")
                .confirmPassword("mismatchpass")
                .build();
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(mismatchReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("xác nhận không khớp")));

        // C. Password with only lowercase (e.g. "onlylowercase" >= 6 chars) -> ACCEPTED! (Relaxed policy)
        ResetPasswordRequest validResetReq = ResetPasswordRequest.builder()
                .email(email)
                .resetToken(resetToken)
                .newPassword("onlylowercase")
                .confirmPassword("onlylowercase")
                .build();
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validResetReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", containsString("thành công")));

        // Token is burned and deleted from database!
        assertTrue(tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId()).isEmpty());

        // D. Replay attack: Using the same resetToken again -> 400 (Single-use enforcement)
        authRateLimiter.clear();
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validResetReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("không tồn tại hoặc đã hết hạn")));

        // E. Verify that Change Password STILL enforces strong password policy (requires special char, uppercase, etc.)
        User updatedUser = userRepository.findByEmail(email).orElseThrow();
        String validJwt = jwtTokenProvider.generateToken(updatedUser);

        // Attempting to change password to a weak password without special character -> 400!
        ChangePasswordRequest weakChangeReq = new ChangePasswordRequest("onlylowercase", "NoSpecial123", "NoSpecial123");
        mockMvc.perform(post("/api/auth/change-password")
                        .header("Authorization", "Bearer " + validJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(weakChangeReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("ký tự đặc biệt")));
    }
}
