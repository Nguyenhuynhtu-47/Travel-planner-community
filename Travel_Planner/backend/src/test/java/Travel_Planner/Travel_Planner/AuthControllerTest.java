package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.request.ResendVerificationRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest;
import Travel_Planner.Travel_Planner.model.EmailVerificationToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.EmailVerificationTokenRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.AuthRateLimiter;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.impl.EmailVerificationServiceImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
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

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Date;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class AuthControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EmailVerificationTokenRepository tokenRepository;

    @Value("${auth.otp.pepper:travel-planner-otp-hmac-secret-pepper-2026}")
    private String pepper;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private AuthRateLimiter authRateLimiter;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
        authRateLimiter.clear();
        cleanDatabaseTables();
    }

    @AfterEach
    void tearDown() {
        authRateLimiter.clear();
        cleanDatabaseTables();
    }

    private void cleanDatabaseTables() {
        // Safe, deterministic database cleanup in topological leaf-to-root order.
        // Foreign key checks remain 100% strictly enabled at all times.
        jdbcTemplate.execute("UPDATE conversations SET last_message_id = NULL");
        jdbcTemplate.execute("UPDATE itineraries SET original_itinerary_id = NULL");
        jdbcTemplate.execute("UPDATE comments SET parent_comment_id = NULL, root_comment_id = NULL");
        jdbcTemplate.execute("DELETE FROM post_media");
        jdbcTemplate.execute("DELETE FROM post_comments");
        jdbcTemplate.execute("DELETE FROM post_likes");
        jdbcTemplate.execute("DELETE FROM post_reports");
        jdbcTemplate.execute("DELETE FROM posts");
        jdbcTemplate.execute("DELETE FROM comments");
        jdbcTemplate.execute("DELETE FROM ratings");
        jdbcTemplate.execute("DELETE FROM favorites");
        jdbcTemplate.execute("DELETE FROM saved_itineraries");
        jdbcTemplate.execute("DELETE FROM itinerary_shares");
        jdbcTemplate.execute("DELETE FROM offline_downloads");
        jdbcTemplate.execute("DELETE FROM activities");
        jdbcTemplate.execute("DELETE FROM itinerary_places");
        jdbcTemplate.execute("DELETE FROM itinerary_days");
        jdbcTemplate.execute("DELETE FROM itineraries");
        jdbcTemplate.execute("DELETE FROM media_assets");
        jdbcTemplate.execute("DELETE FROM conversation_read_states");
        jdbcTemplate.execute("DELETE FROM messages");
        jdbcTemplate.execute("DELETE FROM conversations");
        jdbcTemplate.execute("DELETE FROM follows");
        jdbcTemplate.execute("DELETE FROM friendships");
        jdbcTemplate.execute("DELETE FROM user_blocks");
        jdbcTemplate.execute("DELETE FROM email_verification_tokens");
        jdbcTemplate.execute("DELETE FROM user_messaging_settings");
        jdbcTemplate.execute("DELETE FROM users");
    }

    @Test
    void register_validData_shouldReturn201AndRequiresVerification() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .username("testuser")
                .email("test@example.com")
                .password("Password123")
                .fullName("Test User")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.requiresVerification").value(true))
                .andExpect(jsonPath("$.email").value("test@example.com"))
                .andExpect(jsonPath("$.message").isNotEmpty())
                .andExpect(jsonPath("$.token").doesNotExist())
                .andExpect(jsonPath("$.user.password").doesNotExist())
                .andExpect(jsonPath("$.user.emailVerified").value(false));

        // Verify token created in database
        User createdUser = userRepository.findByUsername("testuser").orElseThrow();
        assertFalse(createdUser.getEmailVerified());
        assertTrue(tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(createdUser.getUserId(), "EMAIL_VERIFICATION").isPresent());
    }

    @Test
    void register_blankFields_shouldReturn400AndValidationErrors() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .username("")
                .email("")
                .password("")
                .fullName("")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.validationErrors.username").isNotEmpty())
                .andExpect(jsonPath("$.validationErrors.email").isNotEmpty())
                .andExpect(jsonPath("$.validationErrors.password").isNotEmpty())
                .andExpect(jsonPath("$.validationErrors.fullName").isNotEmpty());
    }

    @Test
    void register_invalidEmailAndShortPassword_shouldReturn400() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .username("validuser")
                .email("not-an-email")
                .password("123")
                .fullName("User Name")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.validationErrors.email").value("Email không đúng định dạng"))
                .andExpect(jsonPath("$.validationErrors.password").value("Mật khẩu phải có tối thiểu 6 ký tự"));
    }

    @Test
    void register_duplicateUsername_shouldReturn409Conflict() throws Exception {
        User existing = User.builder()
                .username("existinguser")
                .email("existing@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Existing User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build();
        userRepository.save(existing);

        RegisterRequest request = RegisterRequest.builder()
                .username("existinguser")
                .email("other@example.com")
                .password("Password123")
                .fullName("Other User")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message").value("Tên đăng nhập đã tồn tại"));
    }

    @Test
    void register_duplicateEmail_shouldReturn409Conflict() throws Exception {
        User existing = User.builder()
                .username("userone")
                .email("duplicate@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("User One")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build();
        userRepository.save(existing);

        RegisterRequest request = RegisterRequest.builder()
                .username("usertwo")
                .email("duplicate@example.com")
                .password("Password123")
                .fullName("User Two")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message").value("Email đã được sử dụng"));
    }

    @Test
    void login_withUsername_shouldReturn200AndToken() throws Exception {
        User user = User.builder()
                .username("loginuser")
                .email("login@example.com")
                .password(passwordEncoder.encode("MyPassword123"))
                .fullName("Login User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("loginuser")
                .password("MyPassword123")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.username").value("loginuser"))
                .andExpect(jsonPath("$.user.password").doesNotExist());
    }

    @Test
    void login_withEmail_shouldReturn200AndToken() throws Exception {
        User user = User.builder()
                .username("emailuser")
                .email("usermail@example.com")
                .password(passwordEncoder.encode("MyPassword123"))
                .fullName("Email User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("usermail@example.com")
                .password("MyPassword123")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.username").value("emailuser"));
    }

    @Test
    void login_wrongPassword_shouldReturn401() throws Exception {
        User user = User.builder()
                .username("wrongpassuser")
                .email("wrongpass@example.com")
                .password(passwordEncoder.encode("CorrectPassword"))
                .fullName("Wrong Pass User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("wrongpassuser")
                .password("IncorrectPassword")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Tên đăng nhập hoặc mật khẩu không chính xác"));
    }

    @Test
    void login_nonExistentUser_shouldReturn401() throws Exception {
        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("nosuchuser")
                .password("AnyPassword")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Tên đăng nhập hoặc mật khẩu không chính xác"));
    }

    @Test
    void login_bannedUser_shouldReturn403Forbidden() throws Exception {
        User user = User.builder()
                .username("banneduser")
                .email("banned@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Banned User")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("banneduser")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.message").value("Tài khoản của bạn đã bị khóa do vi phạm chính sách"));
    }

    @Test
    void login_inactiveUser_shouldReturn403Forbidden() throws Exception {
        User user = User.builder()
                .username("inactiveuser")
                .email("inactive@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Inactive User")
                .role(Role.USER)
                .status(UserStatus.INACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("inactiveuser")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.message").value("Tài khoản của bạn đang bị vô hiệu hóa"));
    }

    @Test
    void security_healthEndpoint_shouldRemainPublic() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void security_otherEndpointsWithoutToken_shouldBeProtectedAndReturn401() throws Exception {
        mockMvc.perform(get("/api/user/profile"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn"));
    }

    @Test
    void security_adminEndpoint_withoutToken_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn"));
    }

    @Test
    void security_adminEndpoint_withUserRole_shouldReturn403Forbidden() throws Exception {
        User normalUser = User.builder()
                .username("reguser")
                .email("reguser@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Regular User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(normalUser);
        String token = jwtTokenProvider.generateToken(normalUser);

        mockMvc.perform(get("/api/admin/users")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.message").value("Bạn không có quyền truy cập tài nguyên này"));
    }

    @Test
    void security_adminEndpoint_withAdminRole_shouldPassSecurity() throws Exception {
        User adminUser = User.builder()
                .username("sysadmin")
                .email("admin@example.com")
                .password(passwordEncoder.encode("AdminPass123"))
                .fullName("System Admin")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(adminUser);
        String token = jwtTokenProvider.generateToken(adminUser);

        // Access is allowed through security filter chain; since no admin controller is implemented yet,
        // it returns 404 (Not Found), confirming it was NOT rejected by 401 or 403.
        mockMvc.perform(get("/api/admin/users")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void getCurrentUser_withValidToken_shouldReturn200AndUserResponseAndNoPassword() throws Exception {
        User user = User.builder()
                .username("meuser")
                .email("me@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Current User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);
        String token = jwtTokenProvider.generateToken(user);

        mockMvc.perform(get("/api/auth/me")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("meuser"))
                .andExpect(jsonPath("$.email").value("me@example.com"))
                .andExpect(jsonPath("$.fullName").value("Current User"))
                .andExpect(jsonPath("$.role").value("USER"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.password").doesNotExist());
    }

    @Test
    void getCurrentUser_withoutToken_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn"));
    }

    @Test
    void getCurrentUser_withExpiredToken_shouldReturn401() throws Exception {
        SecretKey key = Keys.hmacShaKeyFor("404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970".getBytes(StandardCharsets.UTF_8));
        String expiredToken = Jwts.builder()
                .subject("expireduser")
                .issuedAt(new Date(System.currentTimeMillis() - 200000))
                .expiration(new Date(System.currentTimeMillis() - 100000))
                .signWith(key)
                .compact();

        mockMvc.perform(get("/api/auth/me")
                .header("Authorization", "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn"));
    }

    @Test
    void getCurrentUser_withTamperedToken_shouldReturn401() throws Exception {
        User user = User.builder()
                .username("tamperuser")
                .email("tamper@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Tamper User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);
        String validToken = jwtTokenProvider.generateToken(user);
        String tamperedToken = validToken + "invalid-signature";

        mockMvc.perform(get("/api/auth/me")
                .header("Authorization", "Bearer " + tamperedToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn"));
    }

    @Test
    void getCurrentUser_whenUserBannedAfterTokenIssued_shouldReturn401() throws Exception {
        User user = User.builder()
                .username("bannedlater")
                .email("bannedlater@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Banned Later")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);
        String token = jwtTokenProvider.generateToken(user);

        // Ban user after token has been issued
        user.setStatus(UserStatus.BANNED);
        userRepository.save(user);

        mockMvc.perform(get("/api/auth/me")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Yêu cầu xác thực: Token không hợp lệ hoặc đã hết hạn"));
    }

    @Test
    void register_whenUsernameContainsSpaces_shouldReturn400() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .username("user name with space")
                .email("userspace@example.com")
                .password("Password123")
                .fullName("User Space")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.validationErrors.username").exists());
    }

    @Test
    void register_whenUsernameContainsSpecialCharacters_shouldReturn400() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .username("user@invalid#name!")
                .email("userinvalid@example.com")
                .password("Password123")
                .fullName("User Invalid")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.validationErrors.username").exists());
    }

    @Test
    void cors_whenAllowedOrigin_shouldReturnCorsHeaders() throws Exception {
        mockMvc.perform(options("/api/health")
                .header("Origin", "http://localhost:8081")
                .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:8081"))
                .andExpect(header().string("Access-Control-Allow-Credentials", "true"));
    }

    @Test
    void cors_whenUntrustedOrigin_shouldNotAllowCorsHeaders() throws Exception {
        mockMvc.perform(options("/api/health")
                .header("Origin", "http://malicious-untrusted-site.com")
                .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
    }

    @Test
    void login_rateLimiting_shouldReturn429WhenLimitExceeded() throws Exception {
        User user = User.builder()
                .username("ratelimituser")
                .email("ratelimit@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Rate Limit User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("ratelimituser")
                .password("WrongPassword")
                .build();

        // Capacity is 5; make 5 failed requests
        for (int i = 0; i < 5; i++) {
            mockMvc.perform(post("/api/auth/login")
                    .with(req -> { req.setRemoteAddr("192.168.1.100"); return req; })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isUnauthorized());
        }

        // 6th request from same IP should return 429
        mockMvc.perform(post("/api/auth/login")
                .with(req -> { req.setRemoteAddr("192.168.1.100"); return req; })
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().string("Retry-After", "60"))
                .andExpect(jsonPath("$.status").value(429))
                .andExpect(jsonPath("$.message").value(containsString("quá nhiều yêu cầu")));
    }

    @Test
    void register_rateLimiting_shouldReturn429WhenLimitExceeded() throws Exception {
        // Capacity is 3; perform 3 successful or failed registrations
        for (int i = 0; i < 3; i++) {
            RegisterRequest request = RegisterRequest.builder()
                    .username("rateuser" + i)
                    .email("rateuser" + i + "@example.com")
                    .password("Password123")
                    .fullName("Rate User " + i)
                    .build();

            mockMvc.perform(post("/api/auth/register")
                    .with(req -> { req.setRemoteAddr("192.168.1.101"); return req; })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isCreated());
        }

        // 4th request from same IP should return 429
        RegisterRequest request4 = RegisterRequest.builder()
                .username("rateuser4")
                .email("rateuser4@example.com")
                .password("Password123")
                .fullName("Rate User 4")
                .build();

        mockMvc.perform(post("/api/auth/register")
                .with(req -> { req.setRemoteAddr("192.168.1.101"); return req; })
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request4)))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().string("Retry-After", "600"))
                .andExpect(jsonPath("$.status").value(429))
                .andExpect(jsonPath("$.message").value(containsString("quá nhiều yêu cầu đăng ký")));
    }

    @Test
    void login_nonExistentUser_shouldHaveIdenticalErrorMessageToWrongPassword() throws Exception {
        // Protects against user enumeration by returning identical generic error
        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("ghost_user_does_not_exist")
                .password("SomeRandomPassword123")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Tên đăng nhập hoặc mật khẩu không chính xác"));
    }

    @Test
    void login_unverifiedUser_shouldReturn403Forbidden() throws Exception {
        User user = User.builder()
                .username("unverifieduser")
                .email("unverified@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Unverified User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("unverifieduser")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.message").value("Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email xác thực."));
    }

    @Test
    void verifyEmail_validOtp_shouldReturn200AndToken() throws Exception {
        User user = User.builder()
                .username("verifyuser")
                .email("verify@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Verify User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        String otp = "123456";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(otp, pepper);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        VerifyEmailRequest request = VerifyEmailRequest.builder()
                .email("verify@example.com")
                .code(otp)
                .build();

        mockMvc.perform(post("/api/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.user.email").value("verify@example.com"))
                .andExpect(jsonPath("$.user.emailVerified").value(true));

        // Token should be burned after successful verification
        assertTrue(tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION").isEmpty());

        // User should now be verified and able to login
        User updated = userRepository.findById(user.getUserId()).orElseThrow();
        assertTrue(updated.getEmailVerified());
    }

    @Test
    void verifyEmail_invalidOtp_shouldReturn400AndIncrementAttempts() throws Exception {
        User user = User.builder()
                .username("wrongotpuser")
                .email("wrongotp@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Wrong OTP User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        String otp = "123456";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(otp, pepper);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        VerifyEmailRequest request = VerifyEmailRequest.builder()
                .email("wrongotp@example.com")
                .code("999999")
                .build();

        mockMvc.perform(post("/api/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value(containsString("Mã xác thực không chính xác. Bạn còn 4 lần thử.")));

        // Attempts incremented to 1
        EmailVerificationToken savedToken = tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION").orElseThrow();
        org.junit.jupiter.api.Assertions.assertEquals(1, savedToken.getAttempts());
    }

    @Test
    void verifyEmail_maxAttemptsExceeded_shouldBurnTokenAndReturn400() throws Exception {
        User user = User.builder()
                .username("burnotpuser")
                .email("burnotp@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Burn OTP User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        String otp = "123456";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(otp, pepper);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(4)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .build();
        tokenRepository.save(token);

        VerifyEmailRequest request = VerifyEmailRequest.builder()
                .email("burnotp@example.com")
                .code("999999")
                .build();

        mockMvc.perform(post("/api/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value(containsString("Bạn đã nhập sai quá số lần cho phép.")));

        // Token burned
        assertTrue(tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION").isEmpty());
    }

    @Test
    void verifyEmail_expiredOtp_shouldReturn400() throws Exception {
        User user = User.builder()
                .username("expiredotpuser")
                .email("expiredotp@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Expired OTP User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        String otp = "123456";
        String tokenHash = EmailVerificationServiceImpl.hashOtp(otp, pepper);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().minusMinutes(5))
                .build();
        tokenRepository.save(token);

        VerifyEmailRequest request = VerifyEmailRequest.builder()
                .email("expiredotp@example.com")
                .code("123456")
                .build();

        mockMvc.perform(post("/api/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value(containsString("Mã xác thực đã hết hạn.")));
    }

    @Test
    void verifyEmail_alreadyVerifiedUser_shouldReturn400Or409() throws Exception {
        User user = User.builder()
                .username("alreadyverified")
                .email("already@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Already Verified")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();
        userRepository.save(user);

        VerifyEmailRequest request = VerifyEmailRequest.builder()
                .email("already@example.com")
                .code("123456")
                .build();

        mockMvc.perform(post("/api/auth/verify-email")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Tài khoản đã được kích hoạt trước đó."));
    }

    @Test
    void resendVerification_validEmail_shouldReturn200AndCooldown() throws Exception {
        User user = User.builder()
                .username("resenduser")
                .email("resend@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Resend User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        // Previous token created 2 minutes ago
        String tokenHash = EmailVerificationServiceImpl.hashOtp("111111", pepper);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(13))
                .createdAt(LocalDateTime.now().minusSeconds(120))
                .build();
        tokenRepository.save(token);

        ResendVerificationRequest request = ResendVerificationRequest.builder()
                .email("resend@example.com")
                .build();

        mockMvc.perform(post("/api/auth/resend-verification")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cooldownSeconds").value(60))
                .andExpect(jsonPath("$.message").value(containsString("Mã xác thực mới đã được gửi")));
    }

    @Test
    void resendVerification_cooldownNotElapsed_shouldReturn429TooManyRequests() throws Exception {
        User user = User.builder()
                .username("cooldownuser")
                .email("cooldown@example.com")
                .password(passwordEncoder.encode("Password123"))
                .fullName("Cooldown User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();
        userRepository.save(user);

        // Previous token created 10 seconds ago (cooldown is 60s)
        String tokenHash = EmailVerificationServiceImpl.hashOtp("111111", pepper);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(LocalDateTime.now().plusMinutes(15))
                .createdAt(LocalDateTime.now().minusSeconds(10))
                .build();
        tokenRepository.save(token);

        ResendVerificationRequest request = ResendVerificationRequest.builder()
                .email("cooldown@example.com")
                .build();

        mockMvc.perform(post("/api/auth/resend-verification")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.status").value(429))
                .andExpect(jsonPath("$.message").value(containsString("Vui lòng đợi")));
    }

    @Test
    void resendVerification_nonExistentEmail_shouldReturn200GenericSuccess() throws Exception {
        ResendVerificationRequest request = ResendVerificationRequest.builder()
                .email("ghostemail@example.com")
                .build();

        mockMvc.perform(post("/api/auth/resend-verification")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cooldownSeconds").value(60))
                .andExpect(jsonPath("$.message").value(containsString("Nếu email tồn tại")));
    }

    @Test
    void rateLimiting_verifyEmail_exceedsCapacity_shouldReturn429() throws Exception {
        VerifyEmailRequest request = VerifyEmailRequest.builder()
                .email("verifyrate@example.com")
                .code("123456")
                .build();

        // Limit is 10 req/min
        for (int i = 0; i < 10; i++) {
            mockMvc.perform(post("/api/auth/verify-email")
                    .with(req -> { req.setRemoteAddr("192.168.1.150"); return req; })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isBadRequest());
        }

        // 11th request from same IP should return 429
        mockMvc.perform(post("/api/auth/verify-email")
                .with(req -> { req.setRemoteAddr("192.168.1.150"); return req; })
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().string("Retry-After", "60"))
                .andExpect(jsonPath("$.status").value(429));
    }

    @Test
    void rateLimiting_resendVerification_exceedsCapacity_shouldReturn429() throws Exception {
        ResendVerificationRequest request = ResendVerificationRequest.builder()
                .email("ghostrate@example.com")
                .build();

        // Limit is 3 req/hr
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/auth/resend-verification")
                    .with(req -> { req.setRemoteAddr("192.168.1.151"); return req; })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isOk());
        }

        // 4th request from same IP should return 429
        mockMvc.perform(post("/api/auth/resend-verification")
                .with(req -> { req.setRemoteAddr("192.168.1.151"); return req; })
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().string("Retry-After", "3600"))
                .andExpect(jsonPath("$.status").value(429));
    }

    @Test
    void database_foreignKeyChecks_shouldRemainStrictlyEnabled() {
        Integer fkChecks = jdbcTemplate.queryForObject("SELECT @@FOREIGN_KEY_CHECKS", Integer.class);
        org.junit.jupiter.api.Assertions.assertEquals(1, fkChecks, "Foreign key checks must remain strictly enabled (1)");
    }
}

