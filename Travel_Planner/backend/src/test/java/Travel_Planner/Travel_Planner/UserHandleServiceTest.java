package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.UserHandleBackfillRunner;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateProfileRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.PublicProfileResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.FollowRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.impl.AuthServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.ProfileServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.PublicUserServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.UserHandleServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class UserHandleServiceTest {

    private UserRepository userRepository;
    private UserHandleServiceImpl handleService;
    private PasswordEncoder passwordEncoder;
    private JwtTokenProvider jwtTokenProvider;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        handleService = new UserHandleServiceImpl(userRepository);
        passwordEncoder = mock(PasswordEncoder.class);
        jwtTokenProvider = mock(JwtTokenProvider.class);
    }

    @Test
    @DisplayName("Format validation accepts valid handles and rejects invalid characters and lengths")
    void testHandleFormatValidation() {
        // Valid handles (3-30 chars, lowercase, numbers, dot, underscore)
        assertTrue(handleService.isValidFormat("minhdanh"));
        assertTrue(handleService.isValidFormat("minh.danh"));
        assertTrue(handleService.isValidFormat("danh_289"));
        assertTrue(handleService.isValidFormat("user.123_abc"));
        assertTrue(handleService.isValidFormat("abc")); // min 3

        // Invalid handles
        assertFalse(handleService.isValidFormat("ab")); // too short (<3)
        assertFalse(handleService.isValidFormat("a".repeat(31))); // too long (>30)
        assertFalse(handleService.isValidFormat("minh danh")); // contains space
        assertFalse(handleService.isValidFormat("MinhDanh")); // contains uppercase
        assertFalse(handleService.isValidFormat("minh@danh")); // invalid symbol
        assertFalse(handleService.isValidFormat("minh#danh")); // invalid symbol
        assertFalse(handleService.isValidFormat(null));
    }

    @Test
    @DisplayName("Handle normalization trims and converts to lowercase")
    void testNormalizeHandle() {
        assertEquals("minhdanh", handleService.normalize("  MinhDanh  "));
        assertEquals("minhdanh", handleService.normalize("@minhdanh"));
        assertEquals("minhdanh", handleService.normalize("  @MinhDanh  "));
        assertEquals("traveler.01", handleService.normalize(" TRAVELER.01 "));
        assertNull(handleService.normalize(null));
    }

    @Test
    @DisplayName("generateUniqueHandle MUST derive from fullName, NEVER from login username")
    void testGenerateHandleDerivationDoesNotUseUsername() {
        // When user has fullName "Minh Danh", base is "minhdanh"
        when(userRepository.existsByHandle("minhdanh")).thenReturn(false);

        String handle = handleService.generateUniqueHandle("Minh Danh", 101);
        assertEquals("minhdanh", handle);
        assertFalse(handle.contains("secret_login_username"));
    }

    @Test
    @DisplayName("generateUniqueHandle removes Vietnamese diacritics cleanly")
    void testGenerateHandleRemovesAccents() {
        when(userRepository.existsByHandle(anyString())).thenReturn(false);

        assertEquals("nguyenhoangnam", handleService.generateUniqueHandle("Nguyễn Hoàng Nam", 1));
        assertEquals("dangthuylinh", handleService.generateUniqueHandle("Đặng Thùy Linh", 2));
        assertEquals("vuminhtuan", handleService.generateUniqueHandle("Vũ Minh Tuấn", 3));
    }

    @Test
    @DisplayName("generateUniqueHandle resolves collision with userId or numeric counter")
    void testGenerateHandleCollisionResolution() {
        // "minhdanh" is already taken
        when(userRepository.existsByHandle("minhdanh")).thenReturn(true);
        // "minhdanh_42" is free
        when(userRepository.existsByHandle("minhdanh_42")).thenReturn(false);

        String handle = handleService.generateUniqueHandle("Minh Danh", 42);
        assertEquals("minhdanh_42", handle);

        // If both "minhdanh" and "minhdanh_42" are taken
        when(userRepository.existsByHandle("minhdanh_42")).thenReturn(true);
        when(userRepository.existsByHandle("minhdanh_1")).thenReturn(false);

        String handle2 = handleService.generateUniqueHandle("Minh Danh", 42);
        assertEquals("minhdanh_1", handle2);
    }

    @Test
    @DisplayName("generateUniqueHandle falls back to traveler_<userId> if fullName is null or empty")
    void testGenerateHandleFallbackWhenFullNameMissing() {
        when(userRepository.existsByHandle("traveler_99")).thenReturn(false);

        String handle = handleService.generateUniqueHandle("", 99);
        assertEquals("traveler_99", handle);

        String handleNull = handleService.generateUniqueHandle(null, 99);
        assertEquals("traveler_99", handleNull);
    }

    @Test
    @DisplayName("Registration assigns custom handle if provided, or generates safe default from fullName")
    void testRegisterWithAndWithoutHandle() {
        AuthServiceImpl authService = new AuthServiceImpl(userRepository, passwordEncoder, jwtTokenProvider, handleService);
        when(userRepository.existsByUsername(anyString())).thenReturn(false);
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.existsByHandle(anyString())).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded_pass");
        when(jwtTokenProvider.generateToken(any())).thenReturn("mock_token");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        // Case 1: Custom handle provided
        RegisterRequest reqCustom = RegisterRequest.builder()
                .username("login_user_private")
                .handle("travel.wanderer")
                .email("user@example.com")
                .password("Password123!")
                .fullName("Travel Wanderer")
                .build();

        AuthResponse resCustom = authService.register(reqCustom);
        assertEquals("travel.wanderer", resCustom.getUser().getHandle());
        assertEquals("login_user_private", resCustom.getUser().getUsername());

        // Case 2: No handle provided -> generated automatically from fullName, NOT username
        RegisterRequest reqDefault = RegisterRequest.builder()
                .username("private_login_999")
                .handle(null)
                .email("user2@example.com")
                .password("Password123!")
                .fullName("Lê Hoài An")
                .build();

        AuthResponse resDefault = authService.register(reqDefault);
        assertEquals("lehoaian", resDefault.getUser().getHandle());
        assertNotEquals("private_login_999", resDefault.getUser().getHandle());
    }

    @Test
    @DisplayName("Registration rejects duplicate handle with ConflictException")
    void testRegisterRejectsDuplicateHandle() {
        AuthServiceImpl authService = new AuthServiceImpl(userRepository, passwordEncoder, jwtTokenProvider, handleService);
        when(userRepository.existsByUsername(anyString())).thenReturn(false);
        when(userRepository.existsByEmail(anyString())).thenReturn(false);
        when(userRepository.existsByHandle("existing_handle")).thenReturn(true);

        RegisterRequest req = RegisterRequest.builder()
                .username("newuser")
                .handle("existing_handle")
                .email("new@example.com")
                .password("Password123!")
                .fullName("New User")
                .build();

        assertThrows(ConflictException.class, () -> authService.register(req));
    }

    @Test
    @DisplayName("Profile update changes handle successfully without changing login username")
    void testUpdateProfileChangesHandlePreservingUsername() {
        ProfileServiceImpl profileService = new ProfileServiceImpl(userRepository, handleService);
        User user = User.builder()
                .userId(15)
                .username("secret_login")
                .handle("old_handle")
                .fullName("Nguyen Van A")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .build();
        when(userRepository.findByUsername("secret_login")).thenReturn(Optional.of(user));
        when(userRepository.existsByHandleAndUserIdNot("new.cool.handle", 15)).thenReturn(false);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UpdateProfileRequest updateReq = UpdateProfileRequest.builder()
                .fullName("Nguyen Van A")
                .handle("new.cool.handle")
                .build();

        UserResponse response = profileService.updateCurrentProfile("secret_login", updateReq);

        assertEquals("new.cool.handle", response.getHandle());
        assertEquals("secret_login", response.getUsername()); // Username MUST NOT change!
    }

    @Test
    @DisplayName("Profile update rejects duplicate handle taken by another user")
    void testUpdateProfileRejectsDuplicateHandle() {
        ProfileServiceImpl profileService = new ProfileServiceImpl(userRepository, handleService);
        User user = User.builder()
                .userId(15)
                .username("secret_login")
                .handle("my_handle")
                .fullName("Nguyen Van A")
                .build();
        when(userRepository.findByUsername("secret_login")).thenReturn(Optional.of(user));
        when(userRepository.existsByHandleAndUserIdNot("taken_handle", 15)).thenReturn(true);

        UpdateProfileRequest updateReq = UpdateProfileRequest.builder()
                .fullName("Nguyen Van A")
                .handle("taken_handle")
                .build();

        assertThrows(ConflictException.class, () -> profileService.updateCurrentProfile("secret_login", updateReq));
    }

    @Test
    @DisplayName("Profile update rejects handle with invalid format")
    void testUpdateProfileRejectsInvalidFormat() {
        ProfileServiceImpl profileService = new ProfileServiceImpl(userRepository, handleService);
        User user = User.builder().userId(15).username("user1").build();
        when(userRepository.findByUsername("user1")).thenReturn(Optional.of(user));

        UpdateProfileRequest updateReq = UpdateProfileRequest.builder()
                .fullName("User One")
                .handle("invalid handle with spaces")
                .build();

        assertThrows(BadRequestException.class, () -> profileService.updateCurrentProfile("user1", updateReq));
    }

    @Test
    @DisplayName("Public profile does not expose login username and provides @handle")
    void testPublicProfileDoesNotExposeLoginUsername() {
        FollowRepository followRepo = mock(FollowRepository.class);
        User user = User.builder()
                .userId(20)
                .username("private_login_acc")
                .handle("public_traveler")
                .fullName("John Doe")
                .status(UserStatus.ACTIVE)
                .build();
        when(userRepository.findById(20)).thenReturn(Optional.of(user));
        when(userRepository.findByHandle("public_traveler")).thenReturn(Optional.of(user));

        PublicUserServiceImpl publicUserService = new PublicUserServiceImpl(
                userRepository, followRepo, mock(ItineraryRepository.class), mock(RatingRepository.class));

        PublicProfileResponse byId = publicUserService.getProfile(20, null);
        assertEquals("public_traveler", byId.getHandle());
        assertNull(byId.getUsername()); // Login username is NOT exposed!

        PublicProfileResponse byHandle = publicUserService.getProfileByHandle("@public_traveler", null);
        assertEquals(20, byHandle.getUserId());
        assertEquals("public_traveler", byHandle.getHandle());
        assertNull(byHandle.getUsername());
    }

    @Test
    @DisplayName("UserHandleBackfillRunner safely backfills unique handles without using login username")
    void testBackfillRunnerSafelyAssignsHandles() {
        User legacyUser1 = User.builder().userId(1).username("login_secret1").handle(null).fullName("Tran Van B").build();
        User legacyUser2 = User.builder().userId(2).username("login_secret2").handle("").fullName("Le Thi C").build();

        when(userRepository.findUsersNeedingHandle()).thenReturn(List.of(legacyUser1, legacyUser2));
        when(userRepository.existsByHandle(anyString())).thenReturn(false);

        UserHandleBackfillRunner runner = new UserHandleBackfillRunner(userRepository, handleService);
        runner.run(null);

        verify(userRepository, times(2)).save(any(User.class));
        assertEquals("tranvanb", legacyUser1.getHandle());
        assertEquals("lethic", legacyUser2.getHandle());

        // Assert neither handle equals login username
        assertNotEquals(legacyUser1.getUsername(), legacyUser1.getHandle());
        assertNotEquals(legacyUser2.getUsername(), legacyUser2.getHandle());
    }
}

