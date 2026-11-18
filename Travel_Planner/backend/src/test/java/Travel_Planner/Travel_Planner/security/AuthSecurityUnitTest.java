package Travel_Planner.Travel_Planner.security;

import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.UserHandleService;
import Travel_Planner.Travel_Planner.service.impl.AuthServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.lang.reflect.Field;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class AuthSecurityUnitTest {

    private PasswordEncoder passwordEncoder;
    private UserRepository userRepository;
    private JwtTokenProvider jwtTokenProvider;
    private UserHandleService userHandleService;
    private AuthServiceImpl authService;

    @BeforeEach
    void setUp() {
        passwordEncoder = new BCryptPasswordEncoder();
        userRepository = mock(UserRepository.class);
        jwtTokenProvider = mock(JwtTokenProvider.class);
        userHandleService = mock(UserHandleService.class);
        authService = new AuthServiceImpl(userRepository, passwordEncoder, jwtTokenProvider, userHandleService);
    }

    @Test
    void dummyBcryptHash_isValidCost10HashAndDoesNotThrowException() throws Exception {
        // Retrieve DUMMY_BCRYPT_HASH via reflection to verify actual constant
        Field field = AuthServiceImpl.class.getDeclaredField("DUMMY_BCRYPT_HASH");
        field.setAccessible(true);
        String dummyHash = (String) field.get(null);

        assertNotNull(dummyHash);
        assertTrue(dummyHash.startsWith("$2a$10$") || dummyHash.startsWith("$2b$10$"),
                "DUMMY_BCRYPT_HASH must have standard BCrypt cost 10 prefix");
        assertEquals(60, dummyHash.length(), "Standard BCrypt hash must be 60 characters");

        // Verify passwordEncoder.matches evaluates without throwing IllegalArgumentException
        boolean matches = passwordEncoder.matches("RandomPassword!@#", dummyHash);
        assertFalse(matches, "Dummy hash must not match random password");
    }

    @Test
    void login_whenUserDoesNotExist_runsDummyEvaluationAndThrowsUnauthorized() {
        when(userRepository.findByUsernameOrEmail(anyString(), anyString())).thenReturn(Optional.empty());

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("ghost_user")
                .password("Password123!")
                .build();

        UnauthorizedException ex = assertThrows(UnauthorizedException.class, () -> authService.login(request));
        assertEquals("Tên đăng nhập hoặc mật khẩu không chính xác", ex.getMessage());
    }

    @Test
    void login_whenUserHasNullPassword_runsDummyEvaluationAndThrowsUnauthorized() {
        // Represents an OAuth-only account (e.g. Google Sign-In) without a local password
        User oauthUser = User.builder()
                .userId(1)
                .username("oauth_user")
                .email("oauth@example.com")
                .password(null)
                .fullName("OAuth User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("oauth_user"), eq("oauth_user"))).thenReturn(Optional.of(oauthUser));

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("oauth_user")
                .password("Password123!")
                .build();

        UnauthorizedException ex = assertThrows(UnauthorizedException.class, () -> authService.login(request));
        assertEquals("Tên đăng nhập hoặc mật khẩu không chính xác", ex.getMessage());
    }

    @Test
    void login_whenUserHasWrongPassword_throwsUnauthorized() {
        User user = User.builder()
                .userId(2)
                .username("valid_user")
                .email("valid@example.com")
                .password(passwordEncoder.encode("CorrectPassword123!"))
                .fullName("Valid User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("valid_user"), eq("valid_user"))).thenReturn(Optional.of(user));

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("valid_user")
                .password("WrongPassword123!")
                .build();

        UnauthorizedException ex = assertThrows(UnauthorizedException.class, () -> authService.login(request));
        assertEquals("Tên đăng nhập hoặc mật khẩu không chính xác", ex.getMessage());
    }

    @Test
    void login_whenUserIsBannedWithCorrectPassword_throwsForbidden() {
        User bannedUser = User.builder()
                .userId(3)
                .username("banned_user")
                .email("banned@example.com")
                .password(passwordEncoder.encode("SecretPassword123!"))
                .fullName("Banned User")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("banned_user"), eq("banned_user"))).thenReturn(Optional.of(bannedUser));

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("banned_user")
                .password("SecretPassword123!")
                .build();

        ForbiddenException ex = assertThrows(ForbiddenException.class, () -> authService.login(request));
        assertEquals("Tài khoản của bạn đã bị khóa do vi phạm chính sách", ex.getMessage());
    }

    @Test
    void login_whenUserIsBannedWithWrongPassword_throwsUnauthorizedAndDoesNotLeakBannedStatus() {
        User bannedUser = User.builder()
                .userId(3)
                .username("banned_user")
                .email("banned@example.com")
                .password(passwordEncoder.encode("SecretPassword123!"))
                .fullName("Banned User")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("banned_user"), eq("banned_user"))).thenReturn(Optional.of(bannedUser));

        // Wrong password sent for a banned user
        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("banned_user")
                .password("WrongPassword!")
                .build();

        // Must return generic UnauthorizedException (401), NOT ForbiddenException (403), to prevent status enumeration
        UnauthorizedException ex = assertThrows(UnauthorizedException.class, () -> authService.login(request));
        assertEquals("Tên đăng nhập hoặc mật khẩu không chính xác", ex.getMessage());
    }

    @Test
    void login_whenUserIsInactiveWithCorrectPassword_throwsForbidden() {
        User inactiveUser = User.builder()
                .userId(4)
                .username("inactive_user")
                .email("inactive@example.com")
                .password(passwordEncoder.encode("SecretPassword123!"))
                .fullName("Inactive User")
                .role(Role.USER)
                .status(UserStatus.INACTIVE)
                .emailVerified(true)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("inactive_user"), eq("inactive_user"))).thenReturn(Optional.of(inactiveUser));

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("inactive_user")
                .password("SecretPassword123!")
                .build();

        ForbiddenException ex = assertThrows(ForbiddenException.class, () -> authService.login(request));
        assertEquals("Tài khoản của bạn đang bị vô hiệu hóa", ex.getMessage());
    }

    @Test
    void login_whenUserIsUnverifiedWithCorrectPassword_throwsForbidden() {
        User unverifiedUser = User.builder()
                .userId(5)
                .username("unverified_user")
                .email("unverified@example.com")
                .password(passwordEncoder.encode("SecretPassword123!"))
                .fullName("Unverified User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("unverified_user"), eq("unverified_user"))).thenReturn(Optional.of(unverifiedUser));

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("unverified_user")
                .password("SecretPassword123!")
                .build();

        ForbiddenException ex = assertThrows(ForbiddenException.class, () -> authService.login(request));
        assertEquals("Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email xác thực.", ex.getMessage());
    }

    @Test
    void login_whenUserIsUnverifiedWithWrongPassword_throwsUnauthorizedAndDoesNotLeakUnverifiedStatus() {
        User unverifiedUser = User.builder()
                .userId(5)
                .username("unverified_user")
                .email("unverified@example.com")
                .password(passwordEncoder.encode("SecretPassword123!"))
                .fullName("Unverified User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("unverified_user"), eq("unverified_user"))).thenReturn(Optional.of(unverifiedUser));

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("unverified_user")
                .password("WrongPassword123!")
                .build();

        UnauthorizedException ex = assertThrows(UnauthorizedException.class, () -> authService.login(request));
        assertEquals("Tên đăng nhập hoặc mật khẩu không chính xác", ex.getMessage());
    }

    @Test
    void login_whenUserIsVerifiedWithCorrectPassword_returnsAuthResponse() {
        User verifiedUser = User.builder()
                .userId(6)
                .username("verified_user")
                .email("verified@example.com")
                .password(passwordEncoder.encode("SecretPassword123!"))
                .fullName("Verified User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build();

        when(userRepository.findByUsernameOrEmail(eq("verified_user"), eq("verified_user"))).thenReturn(Optional.of(verifiedUser));
        when(jwtTokenProvider.generateToken(eq(verifiedUser), any())).thenReturn("fake-jwt-token");

        LoginRequest request = LoginRequest.builder()
                .usernameOrEmail("verified_user")
                .password("SecretPassword123!")
                .build();

        Travel_Planner.Travel_Planner.dto.response.AuthResponse response = authService.login(request);
        assertNotNull(response);
        assertEquals("fake-jwt-token", response.getToken());
        assertTrue(response.getUser().getEmailVerified());
    }

    @Test
    void authRateLimiter_resetAccountDoesNotResetIpBucket() {
        AuthRateLimiter limiter = new AuthRateLimiter(true, 2, 1, 3, 10, 2, 1);

        String ip = "192.168.1.50";
        String account = "test_account";

        // Consume 2 tokens for this IP and account
        assertTrue(limiter.tryConsumeLogin(ip, account));
        assertTrue(limiter.tryConsumeLogin(ip, account));

        // 3rd attempt: IP bucket is exhausted
        assertFalse(limiter.tryConsumeLogin(ip, account));

        // Reset account bucket
        limiter.resetAccount(account);

        // IP bucket must STILL be exhausted (resetAccount must not reset IP limit)
        assertFalse(limiter.tryConsumeLogin(ip, account), "Resetting account must not reset the IP rate limiter bucket");
    }
}
