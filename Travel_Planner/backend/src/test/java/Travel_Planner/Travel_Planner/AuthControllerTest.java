package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.hamcrest.Matchers.*;
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
    private ItineraryRepository itineraryRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private ObjectMapper objectMapper;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        this.mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
        ratingRepository.deleteAll();
        itineraryRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void register_validData_shouldReturn201AndTokenAndNoPassword() throws Exception {
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
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.user.username").value("testuser"))
                .andExpect(jsonPath("$.user.email").value("test@example.com"))
                .andExpect(jsonPath("$.user.fullName").value("Test User"))
                .andExpect(jsonPath("$.user.role").value("USER"))
                .andExpect(jsonPath("$.user.status").value("ACTIVE"))
                .andExpect(jsonPath("$.user.password").doesNotExist());
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
}

