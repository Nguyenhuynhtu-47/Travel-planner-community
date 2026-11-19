package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.ChangePasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.ResetPasswordRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.model.PasswordResetToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserSession;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserSessionStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.PasswordResetTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.UserSessionRepository;
import Travel_Planner.Travel_Planner.security.AuthRateLimiter;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.impl.PasswordResetServiceImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
public class SessionManagementIntegrationTest {

    @Autowired
    private WebApplicationContext context;

    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserSessionRepository userSessionRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private AuthRateLimiter authRateLimiter;

    @Autowired(required = false)
    private PasswordResetTokenRepository passwordResetTokenRepository;

    @org.springframework.beans.factory.annotation.Value("${auth.password-reset.pepper:test-travel-planner-pwd-reset-hmac-secret-pepper-2026}")
    private String pepper;

    private User testUser1;
    private User testUser2;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders
                .webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        tearDown();

        testUser1 = userRepository.save(User.builder()
                .username("sessionuser1")
                .handle("sessionuser1")
                .email("sessionuser1@example.com")
                .password(passwordEncoder.encode("Password123!"))
                .fullName("Session User One")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        testUser2 = userRepository.save(User.builder()
                .username("sessionuser2")
                .handle("sessionuser2")
                .email("sessionuser2@example.com")
                .password(passwordEncoder.encode("Password123!"))
                .fullName("Session User Two")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        authRateLimiter.clear();
    }

    @AfterEach
    void tearDown() {
        if (authRateLimiter != null) {
            authRateLimiter.clear();
        }
        if (passwordResetTokenRepository != null) {
            passwordResetTokenRepository.deleteAll();
        }
        userSessionRepository.deleteAll();
        userRepository.findByUsername("sessionuser1").ifPresent(userRepository::delete);
        userRepository.findByUsername("sessionuser2").ifPresent(userRepository::delete);
    }

    @Test
    @DisplayName("Login creates active session with device info and generates JWT with sessionId")
    void login_createsSessionAndValidToken() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        MvcResult result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Device-Info", "Pixel 8 Pro (Android 14)")
                        .header("User-Agent", "TravelPlanner-Mobile/1.0")
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andReturn();

        AuthResponse authResponse = objectMapper.readValue(result.getResponse().getContentAsString(), AuthResponse.class);
        String token = authResponse.getToken();

        // 1. Token contains sessionId claim
        String sessionId = jwtTokenProvider.getSessionIdFromToken(token);
        assertThat(sessionId).isNotNull().isNotBlank();

        // 2. Session exists in database with ACTIVE status and device info
        Optional<UserSession> sessionOpt = userSessionRepository.findBySessionId(sessionId);
        assertThat(sessionOpt).isPresent();
        UserSession session = sessionOpt.get();
        assertThat(session.getStatus()).isEqualTo(UserSessionStatus.ACTIVE);
        assertThat(session.getDeviceInfo()).isEqualTo("Pixel 8 Pro (Android 14)");
        assertThat(session.getUser().getUserId()).isEqualTo(testUser1.getUserId());

        // 3. Token can access protected endpoint
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("sessionuser1")));
    }

    @Test
    @DisplayName("Server-side logout revokes current session, preventing further API access with that JWT")
    void logout_revokesSession_subsequentRequestsReturn401() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();

        AuthResponse authResponse = objectMapper.readValue(loginResult.getResponse().getContentAsString(), AuthResponse.class);
        String token = authResponse.getToken();
        String sessionId = jwtTokenProvider.getSessionIdFromToken(token);

        // Pre-condition: token works
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        // Perform server-side logout
        mockMvc.perform(post("/api/auth/logout")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", is("Đăng xuất thành công")));

        // Verify session status is REVOKED in database
        UserSession session = userSessionRepository.findBySessionId(sessionId).orElseThrow();
        assertThat(session.getStatus()).isEqualTo(UserSessionStatus.REVOKED);

        // Subsequent API call with the revoked token returns 401 Unauthorized
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("GET /api/auth/sessions returns active sessions with isCurrentSession flag")
    void getSessions_returnsSessionsWithCurrentSessionFlag() throws Exception {
        // Device 1 login
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        MvcResult login1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Device-Info", "Laptop (Chrome)")
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();
        String token1 = objectMapper.readValue(login1.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String session1Id = jwtTokenProvider.getSessionIdFromToken(token1);

        // Device 2 login
        MvcResult login2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Device-Info", "Phone (iOS)")
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();
        String token2 = objectMapper.readValue(login2.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String session2Id = jwtTokenProvider.getSessionIdFromToken(token2);

        // Query sessions from Device 2
        mockMvc.perform(get("/api/auth/sessions")
                        .header("Authorization", "Bearer " + token2))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[?(@.sessionId == '" + session2Id + "')].isCurrentSession").value(true))
                .andExpect(jsonPath("$[?(@.sessionId == '" + session1Id + "')].isCurrentSession").value(false));
    }

    @Test
    @DisplayName("Revoking specific session revokes only that device without affecting other devices")
    void revokeSession_revokesOnlyTargetDevice() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        // Device 1
        MvcResult login1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Device-Info", "Device 1")
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token1 = objectMapper.readValue(login1.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String session1Id = jwtTokenProvider.getSessionIdFromToken(token1);

        // Device 2
        MvcResult login2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("X-Device-Info", "Device 2")
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token2 = objectMapper.readValue(login2.getResponse().getContentAsString(), AuthResponse.class).getToken();

        // From Device 2, revoke Device 1's session
        mockMvc.perform(post("/api/auth/sessions/" + session1Id + "/revoke")
                        .header("Authorization", "Bearer " + token2))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.revokedCount", is(1)));

        // Device 1 is now rejected (401)
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + token1))
                .andExpect(status().isUnauthorized());

        // Device 2 is still authenticated (200 OK)
        mockMvc.perform(get("/api/auth/me")
                        .header("Authorization", "Bearer " + token2))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Security Isolation: User cannot revoke session belonging to another user (403 Forbidden)")
    void revokeSession_crossUser_returnsForbidden() throws Exception {
        // User 1 logs in
        LoginRequest login1 = new LoginRequest();
        login1.setUsernameOrEmail("sessionuser1");
        login1.setPassword("Password123!");
        MvcResult res1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login1)))
                .andExpect(status().isOk()).andReturn();
        String session1Id = jwtTokenProvider.getSessionIdFromToken(
                objectMapper.readValue(res1.getResponse().getContentAsString(), AuthResponse.class).getToken()
        );

        // User 2 logs in
        LoginRequest login2 = new LoginRequest();
        login2.setUsernameOrEmail("sessionuser2");
        login2.setPassword("Password123!");
        MvcResult res2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login2)))
                .andExpect(status().isOk()).andReturn();
        String token2 = objectMapper.readValue(res2.getResponse().getContentAsString(), AuthResponse.class).getToken();

        // User 2 attempts to revoke User 1's session
        mockMvc.perform(post("/api/auth/sessions/" + session1Id + "/revoke")
                        .header("Authorization", "Bearer " + token2))
                .andExpect(status().isForbidden());

        // User 1's session remains ACTIVE
        UserSession session = userSessionRepository.findBySessionId(session1Id).orElseThrow();
        assertThat(session.getStatus()).isEqualTo(UserSessionStatus.ACTIVE);
    }

    @Test
    @DisplayName("Revoke-others revokes all active sessions except the current one")
    void revokeOthers_revokesAllExceptCurrent() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        // Device 1
        MvcResult res1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token1 = objectMapper.readValue(res1.getResponse().getContentAsString(), AuthResponse.class).getToken();

        // Device 2
        MvcResult res2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token2 = objectMapper.readValue(res2.getResponse().getContentAsString(), AuthResponse.class).getToken();

        // Device 3
        MvcResult res3 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token3 = objectMapper.readValue(res3.getResponse().getContentAsString(), AuthResponse.class).getToken();

        // From Device 3, revoke all other devices
        mockMvc.perform(post("/api/auth/sessions/revoke-others")
                        .header("Authorization", "Bearer " + token3))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.revokedCount", is(2)));

        // Device 1 & 2 are 401
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token1))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token2))
                .andExpect(status().isUnauthorized());

        // Device 3 is still 200 OK
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token3))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Revoke-all revokes all sessions for user including current one")
    void revokeAll_revokesAllSessions() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        MvcResult res1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token1 = objectMapper.readValue(res1.getResponse().getContentAsString(), AuthResponse.class).getToken();

        MvcResult res2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token2 = objectMapper.readValue(res2.getResponse().getContentAsString(), AuthResponse.class).getToken();

        // Call revoke-all
        mockMvc.perform(post("/api/auth/sessions/revoke-all")
                        .header("Authorization", "Bearer " + token2))
                .andExpect(status().isOk());

        // Both are now 401
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token1))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token2))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Password Change: Synchronously revokes all old sessions in DB, rejects old JWTs, and preserves new session")
    void changePassword_revokesAllOldSessions_andSyncsStatus() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        // Device 1 login
        MvcResult res1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token1 = objectMapper.readValue(res1.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String sessionId1 = jwtTokenProvider.getSessionIdFromToken(token1);

        // Device 2 login
        MvcResult res2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token2 = objectMapper.readValue(res2.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String sessionId2 = jwtTokenProvider.getSessionIdFromToken(token2);

        // Before change: both sessions are ACTIVE
        assertThat(userSessionRepository.findBySessionId(sessionId1).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.ACTIVE);
        assertThat(userSessionRepository.findBySessionId(sessionId2).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.ACTIVE);

        // Device 1 changes password
        String newPassword = "NewValidPassword123!";
        ChangePasswordRequest changeReq = new ChangePasswordRequest("Password123!", newPassword, newPassword);
        mockMvc.perform(post("/api/auth/change-password")
                        .header("Authorization", "Bearer " + token1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(changeReq)))
                .andExpect(status().isOk());

        // Verify database: ALL old sessions are now REVOKED (none remain ACTIVE)
        assertThat(userSessionRepository.findBySessionId(sessionId1).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.REVOKED);
        assertThat(userSessionRepository.findBySessionId(sessionId2).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.REVOKED);

        // Subsequent requests with old tokens are REJECTED (401 Unauthorized)
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token1))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token2))
                .andExpect(status().isUnauthorized());

        // Login with new password succeeds and creates a brand-new ACTIVE session
        LoginRequest newLoginReq = new LoginRequest();
        newLoginReq.setUsernameOrEmail("sessionuser1");
        newLoginReq.setPassword(newPassword);

        MvcResult res3 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(newLoginReq)))
                .andExpect(status().isOk()).andReturn();
        String token3 = objectMapper.readValue(res3.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String sessionId3 = jwtTokenProvider.getSessionIdFromToken(token3);

        // New session is ACTIVE, works on protected endpoint
        assertThat(userSessionRepository.findBySessionId(sessionId3).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.ACTIVE);
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token3))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("sessionuser1")));

        // Listing sessions confirms old sessions are REVOKED and only new session is ACTIVE
        mockMvc.perform(get("/api/auth/sessions").header("Authorization", "Bearer " + token3))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(3)));
    }

    @Test
    @DisplayName("Password Reset: Synchronously revokes all old sessions in DB, rejects old JWTs, and preserves new session")
    void resetPassword_revokesAllOldSessions_andSyncsStatus() throws Exception {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("sessionuser1");
        loginRequest.setPassword("Password123!");

        // Device 1 login
        MvcResult res1 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token1 = objectMapper.readValue(res1.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String sessionId1 = jwtTokenProvider.getSessionIdFromToken(token1);

        // Device 2 login
        MvcResult res2 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        String token2 = objectMapper.readValue(res2.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String sessionId2 = jwtTokenProvider.getSessionIdFromToken(token2);

        // Before reset: both sessions are ACTIVE
        assertThat(userSessionRepository.findBySessionId(sessionId1).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.ACTIVE);
        assertThat(userSessionRepository.findBySessionId(sessionId2).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.ACTIVE);

        // Create reset token fixture
        String rawOtp = "987654";
        String tokenHash = PasswordResetServiceImpl.hashOtp(rawOtp, pepper);
        PasswordResetToken resetTokenFixture = PasswordResetToken.builder()
                .user(testUser1)
                .tokenHash(tokenHash)
                .attempts(0)
                .expiresAt(java.time.LocalDateTime.now().plusMinutes(15))
                .createdAt(java.time.LocalDateTime.now())
                .build();
        if (passwordResetTokenRepository != null) {
            passwordResetTokenRepository.save(resetTokenFixture);
        }

        // Perform password reset
        String resetNewPassword = "BrandNewResetPass123!";
        ResetPasswordRequest resetReq = new ResetPasswordRequest("sessionuser1@example.com", rawOtp, resetNewPassword, resetNewPassword);
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(resetReq)))
                .andExpect(status().isOk());

        // Verify database: ALL old sessions are now REVOKED (none remain ACTIVE)
        assertThat(userSessionRepository.findBySessionId(sessionId1).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.REVOKED);
        assertThat(userSessionRepository.findBySessionId(sessionId2).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.REVOKED);

        // Both old tokens are rejected with 401
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token1))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token2))
                .andExpect(status().isUnauthorized());

        // Login with new password succeeds and creates a brand-new ACTIVE session
        LoginRequest newLoginReq = new LoginRequest();
        newLoginReq.setUsernameOrEmail("sessionuser1");
        newLoginReq.setPassword(resetNewPassword);

        MvcResult res3 = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(newLoginReq)))
                .andExpect(status().isOk()).andReturn();
        String token3 = objectMapper.readValue(res3.getResponse().getContentAsString(), AuthResponse.class).getToken();
        String sessionId3 = jwtTokenProvider.getSessionIdFromToken(token3);

        // New session is ACTIVE, works on protected endpoint
        assertThat(userSessionRepository.findBySessionId(sessionId3).orElseThrow().getStatus()).isEqualTo(UserSessionStatus.ACTIVE);
        mockMvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token3))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username", is("sessionuser1")));
    }
}
