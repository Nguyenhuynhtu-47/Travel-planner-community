package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateProfileRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.PublicProfileResponse;
import Travel_Planner.Travel_Planner.dto.response.RegisterResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserMessagingSettingsRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.AuthService;
import Travel_Planner.Travel_Planner.service.MessagingSettingsService;
import Travel_Planner.Travel_Planner.service.ProfileService;
import Travel_Planner.Travel_Planner.service.PublicUserService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.data.domain.PageRequest;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class UserHandleDatabasePersistenceTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AuthService authService;

    @Autowired
    private ProfileService profileService;

    @Autowired
    private PublicUserService publicUserService;

    @Autowired
    private MessagingSettingsService messagingSettingsService;

    @Autowired
    private UserMessagingSettingsRepository messagingSettingsRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private String testUsername1;
    private String testUsername2;
    private String testHandle1;
    private String testHandle2;

    @BeforeEach
    void setUp() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        testUsername1 = "testuser_" + suffix;
        testUsername2 = "testuser2_" + suffix;
        testHandle1 = "handle_" + suffix;
        testHandle2 = "handle2_" + suffix;
    }

    @AfterEach
    void tearDown() {
        try {
            jdbcTemplate.update("DELETE FROM email_verification_tokens WHERE user_id IN (SELECT user_id FROM (SELECT user_id FROM users WHERE username IN (?, ?)) AS temp)", testUsername1, testUsername2);
            userRepository.findByUsername(testUsername1).ifPresent(userRepository::delete);
            userRepository.findByUsername(testUsername1).ifPresent(user -> {
                messagingSettingsRepository.deleteById(user.getUserId());
                userRepository.delete(user);
            });
            userRepository.findByUsername(testUsername2).ifPresent(userRepository::delete);
        } catch (Exception ignored) {
        }
    }

    @Test
    @DisplayName("Lưu quyền riêng tư lần đầu tạo row @MapsId mà không lỗi Hibernate merge")
    void testFirstMessagingSettingsUpdatePersistsWithMapsId() {
        authService.register(RegisterRequest.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("Password123!")
                .fullName("Messaging Settings Test")
                .build());

        var updated = messagingSettingsService.update(InboundMessagePolicy.FRIENDS_ONLY, testUsername1);
        var reloaded = messagingSettingsService.get(testUsername1);

        assertEquals(InboundMessagePolicy.FRIENDS_ONLY, updated.getInboundPolicy());
        assertEquals(InboundMessagePolicy.FRIENDS_ONLY, reloaded.getInboundPolicy());
        assertEquals(1, jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM user_messaging_settings WHERE user_id = ?",
                Integer.class,
                userRepository.findByUsername(testUsername1).orElseThrow().getUserId()));
    }

    @Test
    @DisplayName("1. Đăng ký tài khoản mới và xác minh handle được lưu trực tiếp trong MySQL")
    void testRegistrationPersistsHandleInMySQL() {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("Password123!")
                .fullName("Test Persistence User")
                .build();

        RegisterResponse authResponse = authService.register(registerRequest);
        assertTrue(authResponse.getRequiresVerification());
        assertEquals(testHandle1, authResponse.getUser().getHandle());

        // Verify directly in MySQL using JDBC query
        String dbHandle = jdbcTemplate.queryForObject(
                "SELECT handle FROM users WHERE username = ?",
                String.class,
                testUsername1
        );
        assertEquals(testHandle1, dbHandle, "Handle must be persisted directly in MySQL users table!");
    }

    @Test
    @DisplayName("2 & 3. Đăng xuất rồi đăng nhập lại, handle vẫn tồn tại và không thay đổi")
    void testLoginRetrievesPersistedHandle() {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("Password123!")
                .fullName("Login Test User")
                .build();

        authService.register(registerRequest);
        jdbcTemplate.update("UPDATE users SET email_verified = TRUE WHERE username = ?", testUsername1);

        // Simulate new login session
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setUsernameOrEmail(testUsername1);
        loginRequest.setPassword("Password123!");

        AuthResponse loginResponse = authService.login(loginRequest);
        assertNotNull(loginResponse.getToken());
        assertEquals(testHandle1, loginResponse.getUser().getHandle(), "Handle must remain intact upon re-login!");
    }

    @Test
    @DisplayName("Tìm tên tiếng Việt theo tiền tố không dấu dùng collation MySQL hiện tại")
    void testSearchMatchesVietnameseNameWithoutDiacritics() {
        User user = User.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("not-used-in-test")
                .fullName("Nguyễn Huệ")
                .status(UserStatus.ACTIVE)
                .build();
        userRepository.saveAndFlush(user);

        var result = userRepository.searchActiveUsers("nguyen%", "nguyen", PageRequest.of(0, 20));

        assertTrue(result.getContent().stream().anyMatch(found -> found.getUserId().equals(user.getUserId())),
                "MySQL search collation should match an unaccented prefix against Nguyễn");
    }

    @Test
    @DisplayName("4. Thay đổi handle và xác minh giá trị mới thực sự được cập nhật trong MySQL")
    void testUpdateProfileUpdatesHandleInMySQL() {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("Password123!")
                .fullName("Original Name")
                .build();

        authService.register(registerRequest);

        String newHandle = "upd_" + testHandle1;
        UpdateProfileRequest updateRequest = UpdateProfileRequest.builder()
                .fullName("Original Name")
                .handle(newHandle)
                .build();

        UserResponse userResponse = profileService.updateCurrentProfile(testUsername1, updateRequest);
        assertEquals(newHandle, userResponse.getHandle());
        assertEquals(testUsername1, userResponse.getUsername()); // Username must NOT change

        // Verify directly in MySQL with SELECT query
        String dbHandle = jdbcTemplate.queryForObject(
                "SELECT handle FROM users WHERE username = ?",
                String.class,
                testUsername1
        );
        assertEquals(newHandle, dbHandle, "Updated handle must be committed directly to MySQL!");

        // Also test updating with leading '@' format
        String newHandleWithAt = "@" + (newHandle.length() > 25 ? newHandle.substring(0, 25) : newHandle) + "v2";
        String expectedHandle = (newHandle.length() > 25 ? newHandle.substring(0, 25) : newHandle) + "v2";
        UpdateProfileRequest updateRequest2 = UpdateProfileRequest.builder()
                .fullName("Original Name")
                .handle(newHandleWithAt)
                .build();
        UserResponse response2 = profileService.updateCurrentProfile(testUsername1, updateRequest2);
        assertEquals(expectedHandle, response2.getHandle());
        String dbHandle2 = jdbcTemplate.queryForObject(
                "SELECT handle FROM users WHERE username = ?",
                String.class,
                testUsername1
        );
        assertEquals(expectedHandle, dbHandle2, "Leading '@' should be cleanly normalized and persisted in MySQL!");
    }

    @Test
    @DisplayName("5. Hai tài khoản không thể sử dụng cùng một handle (Database & Service constraint)")
    void testDuplicateHandleRejected() {
        RegisterRequest user1 = RegisterRequest.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("Password123!")
                .fullName("User One")
                .build();
        authService.register(user1);

        RegisterRequest user2WithSameHandle = RegisterRequest.builder()
                .username(testUsername2)
                .handle(testHandle1) // DUPLICATE HANDLE
                .email(testUsername2 + "@example.com")
                .password("Password123!")
                .fullName("User Two")
                .build();

        assertThrows(ConflictException.class, () -> authService.register(user2WithSameHandle),
                "Should reject registration with duplicate handle!");
    }

    @Test
    @DisplayName("7 & 8. Xem Profile người khác đọc handle từ MySQL và KHÔNG trả username đăng nhập")
    void testPublicProfileReadsHandleFromDatabaseAndHidesUsername() {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .username(testUsername1)
                .handle(testHandle1)
                .email(testUsername1 + "@example.com")
                .password("Password123!")
                .fullName("Public Creator")
                .build();

        RegisterResponse authResponse = authService.register(registerRequest);
        Integer userId = authResponse.getUser().getUserId();

        // Query public profile by userId
        PublicProfileResponse profileById = publicUserService.getProfile(userId, null);
        assertEquals(testHandle1, profileById.getHandle(), "Public profile must return handle from DB!");
        assertNull(profileById.getUsername(), "Public profile MUST NOT expose private login username!");

        // Query public profile by handle
        PublicProfileResponse profileByHandle = publicUserService.getProfileByHandle("@" + testHandle1, null);
        assertEquals(userId, profileByHandle.getUserId());
        assertEquals(testHandle1, profileByHandle.getHandle());
        assertNull(profileByHandle.getUsername());
    }
}
