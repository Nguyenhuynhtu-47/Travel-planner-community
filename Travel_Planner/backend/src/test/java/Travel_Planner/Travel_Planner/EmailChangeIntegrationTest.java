package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.EmailChangeRequestDto;
import Travel_Planner.Travel_Planner.dto.request.EmailChangeVerifyDto;
import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.model.EmailChangeRequest;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserIdentity;
import Travel_Planner.Travel_Planner.model.enums.EmailChangeStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.EmailChangeRequestRepository;
import Travel_Planner.Travel_Planner.repository.UserIdentityRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.UserSessionRepository;
import Travel_Planner.Travel_Planner.security.AuthRateLimiter;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.is;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
public class EmailChangeIntegrationTest {

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
    private EmailChangeRequestRepository emailChangeRequestRepository;

    @Autowired
    private UserIdentityRepository userIdentityRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AuthRateLimiter authRateLimiter;

    @Value("${app.auth.otp.pepper:TravelPlannerDefaultOtpPepper2026SecureKey}")
    private String pepper;

    private User testUser;
    private User otherUser;
    private String userToken;

    @BeforeEach
    void setUp() throws Exception {
        mockMvc = MockMvcBuilders
                .webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        tearDown();

        testUser = userRepository.save(User.builder()
                .username("changeemailuser")
                .handle("changeemailuser")
                .email("original@example.com")
                .password(passwordEncoder.encode("CurrentPass123!"))
                .fullName("Original User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        otherUser = userRepository.save(User.builder()
                .username("otheruser")
                .handle("otheruser")
                .email("taken@example.com")
                .password(passwordEncoder.encode("Password123!"))
                .fullName("Other User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        authRateLimiter.clear();

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail("changeemailuser");
        loginRequest.setPassword("CurrentPass123!");
        MvcResult res = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk()).andReturn();
        userToken = objectMapper.readValue(res.getResponse().getContentAsString(), AuthResponse.class).getToken();
    }

    @AfterEach
    void tearDown() {
        if (authRateLimiter != null) {
            authRateLimiter.clear();
        }
        emailChangeRequestRepository.deleteAll();
        userSessionRepository.deleteAll();
        userIdentityRepository.deleteAll();
        userRepository.findByUsername("changeemailuser").ifPresent(userRepository::delete);
        userRepository.findByUsername("otheruser").ifPresent(userRepository::delete);
        userRepository.findByEmail("newvalid@example.com").ifPresent(userRepository::delete);
    }

    @Test
    @DisplayName("Email Change: Unauthenticated request returns 401 Unauthorized")
    void requestEmailChange_unauthenticated_returns401() throws Exception {
        EmailChangeRequestDto dto = new EmailChangeRequestDto("newvalid@example.com", "CurrentPass123!");
        mockMvc.perform(post("/api/auth/email-change/request")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Email Change: Wrong current password returns 401 Bad Credentials")
    void requestEmailChange_wrongPassword_returns401() throws Exception {
        EmailChangeRequestDto dto = new EmailChangeRequestDto("newvalid@example.com", "WrongPassword!");
        mockMvc.perform(post("/api/auth/email-change/request")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message", containsString("Mật khẩu hiện tại không chính xác")));
    }

    @Test
    @DisplayName("Email Change: New email identical to current email returns 400 Bad Request")
    void requestEmailChange_sameEmail_returns400() throws Exception {
        EmailChangeRequestDto dto = new EmailChangeRequestDto("original@example.com", "CurrentPass123!");
        mockMvc.perform(post("/api/auth/email-change/request")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("không được trùng")));
    }

    @Test
    @DisplayName("Email Change: New email already taken returns 409 Conflict")
    void requestEmailChange_alreadyTaken_returns409() throws Exception {
        EmailChangeRequestDto dto = new EmailChangeRequestDto("taken@example.com", "CurrentPass123!");
        mockMvc.perform(post("/api/auth/email-change/request")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message", containsString("Email này đã được sử dụng")));
    }

    @Test
    @DisplayName("Email Change: Valid request creates pending request and dispatches OTP")
    void requestEmailChange_validRequest_createsPendingRequest() throws Exception {
        EmailChangeRequestDto dto = new EmailChangeRequestDto("newvalid@example.com", "CurrentPass123!");
        mockMvc.perform(post("/api/auth/email-change/request")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.newEmail", is("newvalid@example.com")));

        // Verify pending request in database
        Optional<EmailChangeRequest> opt = emailChangeRequestRepository
                .findTopByUser_UserIdAndNewEmailAndStatusOrderByCreatedAtDesc(testUser.getUserId(), "newvalid@example.com", EmailChangeStatus.PENDING);
        assertThat(opt).isPresent();
        EmailChangeRequest req = opt.get();
        assertThat(req.getOldEmail()).isEqualTo("original@example.com");
        assertThat(req.getOtpHash()).isNotBlank();
        assertThat(req.getExpiresAt()).isAfter(LocalDateTime.now());
    }

    @Test
    @DisplayName("Email Change: Full verification flow updates user email and preserves Google Identity")
    void verifyEmailChange_validOtp_updatesEmailAndPreservesGoogleIdentity() throws Exception {
        // 1. Link a Google identity to the user first
        userIdentityRepository.save(UserIdentity.builder()
                .user(testUser)
                .provider("GOOGLE")
                .providerSubject("google-sub-123456789")
                .email("original@example.com")
                .build());

        // 2. Request email change
        EmailChangeRequestDto reqDto = new EmailChangeRequestDto("newvalid@example.com", "CurrentPass123!");
        mockMvc.perform(post("/api/auth/email-change/request")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reqDto)))
                .andExpect(status().isOk());

        // Fetch pending request and set known OTP hash "123456"
        EmailChangeRequest changeRequest = emailChangeRequestRepository
                .findTopByUser_UserIdAndNewEmailAndStatusOrderByCreatedAtDesc(testUser.getUserId(), "newvalid@example.com", EmailChangeStatus.PENDING)
                .orElseThrow();
        changeRequest.setOtpHash(hashOtp("123456", pepper));
        emailChangeRequestRepository.save(changeRequest);

        // 3. Negative check: incorrect OTP returns 400
        EmailChangeVerifyDto wrongDto = new EmailChangeVerifyDto("newvalid@example.com", "000000");
        mockMvc.perform(post("/api/auth/email-change/verify")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongDto)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("Mã xác thực không chính xác")));

        // 4. Correct OTP verifies successfully
        EmailChangeVerifyDto verifyDto = new EmailChangeVerifyDto("newvalid@example.com", "123456");
        mockMvc.perform(post("/api/auth/email-change/verify")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyDto)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.newEmail", is("newvalid@example.com")));

        // 5. Verify user in database has new email and emailVerified=true
        User updatedUser = userRepository.findById(testUser.getUserId()).orElseThrow();
        assertThat(updatedUser.getEmail()).isEqualTo("newvalid@example.com");
        assertThat(updatedUser.getEmailVerified()).isTrue();

        // 6. Verify Google Identity is still linked to this user!
        Optional<UserIdentity> preservedIdentity = userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-123456789");
        assertThat(preservedIdentity).isPresent();
        assertThat(preservedIdentity.get().getUser().getUserId()).isEqualTo(testUser.getUserId());

        // 7. User can now login with new email
        LoginRequest newLogin = new LoginRequest();
        newLogin.setUsernameOrEmail("newvalid@example.com");
        newLogin.setPassword("CurrentPass123!");
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(newLogin)))
                .andExpect(status().isOk());
    }

    private String hashOtp(String otp, String pepper) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(pepper.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKey);
            byte[] hmacBytes = mac.doFinal(otp.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hmacBytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
