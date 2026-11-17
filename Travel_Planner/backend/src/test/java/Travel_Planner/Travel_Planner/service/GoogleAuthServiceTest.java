package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.GoogleAuthRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleLinkRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.GoogleLinkResponse;
import Travel_Planner.Travel_Planner.exception.AccountConflictException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserIdentity;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserIdentityRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.GoogleTokenVerifier;
import Travel_Planner.Travel_Planner.security.GoogleUserInfo;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.impl.GoogleAuthServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GoogleAuthServiceTest {

    @Mock
    private GoogleTokenVerifier googleTokenVerifier;

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserIdentityRepository userIdentityRepository;

    @Mock
    private JwtTokenProvider jwtTokenProvider;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private UserHandleService userHandleService;

    private GoogleAuthServiceImpl googleAuthService;

    @BeforeEach
    void setUp() {
        googleAuthService = new GoogleAuthServiceImpl(
                googleTokenVerifier,
                userRepository,
                userIdentityRepository,
                jwtTokenProvider,
                passwordEncoder,
                userHandleService
        );
    }

    private GoogleUserInfo buildSampleGoogleUserInfo(String sub, String email, String name) {
        return GoogleUserInfo.builder()
                .sub(sub)
                .email(email)
                .emailVerified(true)
                .name(name)
                .picture("https://lh3.googleusercontent.com/sample.png")
                .build();
    }

    private User buildSampleUser(Integer id, String username, String email, UserStatus status) {
        return User.builder()
                .userId(id)
                .username(username)
                .handle(username)
                .email(email)
                .password("$2a$10$encodedpassword")
                .fullName("Sample User")
                .role(Role.USER)
                .status(status)
                .emailVerified(true)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
    }

    @Test
    @DisplayName("authenticateWithGoogle: Existing linked account authenticates successfully and issues JWT")
    void authenticateWithGoogle_existingLinkedAccount_success() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-123", "test@example.com", "Test User");
        User user = buildSampleUser(1, "testuser", "test@example.com", UserStatus.ACTIVE);
        UserIdentity identity = UserIdentity.builder()
                .identityId(10)
                .user(user)
                .provider("GOOGLE")
                .providerSubject("google-sub-123")
                .email("test@example.com")
                .build();

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-123"))
                .thenReturn(Optional.of(identity));
        when(jwtTokenProvider.generateToken(user)).thenReturn("jwt.token.value");

        AuthResponse response = googleAuthService.authenticateWithGoogle(new GoogleAuthRequest(tokenStr));

        assertNotNull(response);
        assertEquals("jwt.token.value", response.getToken());
        assertEquals("Bearer", response.getTokenType());
        assertEquals("testuser", response.getUser().getUsername());
        assertEquals("test@example.com", response.getUser().getEmail());
        verify(userRepository, never()).save(any());
    }

    @Test
    @DisplayName("authenticateWithGoogle: Banned user throws ForbiddenException")
    void authenticateWithGoogle_bannedUser_throwsForbidden() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-123", "banned@example.com", "Banned User");
        User user = buildSampleUser(1, "banneduser", "banned@example.com", UserStatus.BANNED);
        UserIdentity identity = UserIdentity.builder()
                .identityId(10)
                .user(user)
                .provider("GOOGLE")
                .providerSubject("google-sub-123")
                .email("banned@example.com")
                .build();

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-123"))
                .thenReturn(Optional.of(identity));

        ForbiddenException ex = assertThrows(ForbiddenException.class,
                () -> googleAuthService.authenticateWithGoogle(new GoogleAuthRequest(tokenStr)));
        assertTrue(ex.getMessage().contains("khóa"));
    }

    @Test
    @DisplayName("authenticateWithGoogle: Inactive user throws ForbiddenException")
    void authenticateWithGoogle_inactiveUser_throwsForbidden() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-123", "inactive@example.com", "Inactive User");
        User user = buildSampleUser(1, "inactiveuser", "inactive@example.com", UserStatus.INACTIVE);
        UserIdentity identity = UserIdentity.builder()
                .identityId(10)
                .user(user)
                .provider("GOOGLE")
                .providerSubject("google-sub-123")
                .email("inactive@example.com")
                .build();

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-123"))
                .thenReturn(Optional.of(identity));

        ForbiddenException ex = assertThrows(ForbiddenException.class,
                () -> googleAuthService.authenticateWithGoogle(new GoogleAuthRequest(tokenStr)));
        assertTrue(ex.getMessage().contains("vô hiệu hóa"));
    }

    @Test
    @DisplayName("authenticateWithGoogle: Unlinked Google sub with existing local email throws AccountConflictException (No auto-linking)")
    void authenticateWithGoogle_existingLocalEmail_throwsAccountConflict() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-456", "local@example.com", "Local User");
        User localUser = buildSampleUser(2, "localuser", "local@example.com", UserStatus.ACTIVE);

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-456"))
                .thenReturn(Optional.empty());
        when(userRepository.findByEmail("local@example.com")).thenReturn(Optional.of(localUser));

        AccountConflictException ex = assertThrows(AccountConflictException.class,
                () -> googleAuthService.authenticateWithGoogle(new GoogleAuthRequest(tokenStr)));
        assertTrue(ex.getMessage().contains("đã được sử dụng"));
        assertTrue(ex.getMessage().contains("liên kết"));
        verify(userRepository, never()).save(any());
        verify(userIdentityRepository, never()).save(any());
    }

    @Test
    @DisplayName("authenticateWithGoogle: New account creates user with unusable password, links identity, and issues JWT")
    void authenticateWithGoogle_newAccount_provisionsUser_success() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-new", "newbie@example.com", "New Traveler");

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-new"))
                .thenReturn(Optional.empty());
        when(userRepository.findByEmail("newbie@example.com")).thenReturn(Optional.empty());
        when(userRepository.existsByUsername(anyString())).thenReturn(false);
        when(userHandleService.generateUniqueHandle(anyString(), isNull())).thenReturn("newbie_handle");
        when(passwordEncoder.encode(anyString())).thenReturn("$2a$10$unusableRandomPasswordHash");

        User savedUser = buildSampleUser(5, "newbie", "newbie@example.com", UserStatus.ACTIVE);
        when(userRepository.save(any(User.class))).thenReturn(savedUser);
        when(jwtTokenProvider.generateToken(savedUser)).thenReturn("jwt.token.newbie");

        AuthResponse response = googleAuthService.authenticateWithGoogle(new GoogleAuthRequest(tokenStr));

        assertNotNull(response);
        assertEquals("jwt.token.newbie", response.getToken());

        // Verify User was saved with emailVerified=true
        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        User capturedUser = userCaptor.getValue();
        assertTrue(capturedUser.getEmailVerified());
        assertEquals("newbie@example.com", capturedUser.getEmail());
        assertEquals("$2a$10$unusableRandomPasswordHash", capturedUser.getPassword());

        // Verify UserIdentity was saved
        ArgumentCaptor<UserIdentity> identityCaptor = ArgumentCaptor.forClass(UserIdentity.class);
        verify(userIdentityRepository).save(identityCaptor.capture());
        UserIdentity capturedIdentity = identityCaptor.getValue();
        assertEquals("GOOGLE", capturedIdentity.getProvider());
        assertEquals("google-sub-new", capturedIdentity.getProviderSubject());
        assertEquals("newbie@example.com", capturedIdentity.getEmail());
    }

    @Test
    @DisplayName("linkGoogleAccount: Authenticated user links Google identity successfully")
    void linkGoogleAccount_success() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-link", "linkme@example.com", "Link Me");
        User user = buildSampleUser(1, "myuser", "myuser@example.com", UserStatus.ACTIVE);

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userRepository.findByUsername("myuser")).thenReturn(Optional.of(user));
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-link"))
                .thenReturn(Optional.empty());
        when(userIdentityRepository.findByUser_UserIdAndProvider(1, "GOOGLE"))
                .thenReturn(Optional.empty());

        GoogleLinkResponse response = googleAuthService.linkGoogleAccount("myuser", new GoogleLinkRequest(tokenStr));

        assertNotNull(response);
        assertTrue(response.getMessage().contains("thành công"));
        assertEquals("linkme@example.com", response.getLinkedEmail());
        assertEquals("GOOGLE", response.getProvider());

        verify(userIdentityRepository).save(any(UserIdentity.class));
    }

    @Test
    @DisplayName("linkGoogleAccount: Sub already linked to the current user returns success info without duplicating")
    void linkGoogleAccount_alreadyLinkedToSelf_returnsSuccess() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-link", "linkme@example.com", "Link Me");
        User user = buildSampleUser(1, "myuser", "myuser@example.com", UserStatus.ACTIVE);
        UserIdentity existingIdentity = UserIdentity.builder()
                .identityId(12)
                .user(user)
                .provider("GOOGLE")
                .providerSubject("google-sub-link")
                .email("linkme@example.com")
                .build();

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userRepository.findByUsername("myuser")).thenReturn(Optional.of(user));
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-link"))
                .thenReturn(Optional.of(existingIdentity));

        GoogleLinkResponse response = googleAuthService.linkGoogleAccount("myuser", new GoogleLinkRequest(tokenStr));

        assertNotNull(response);
        assertTrue(response.getMessage().contains("trước đó"));
        verify(userIdentityRepository, never()).save(any());
    }

    @Test
    @DisplayName("linkGoogleAccount: Sub already linked to ANOTHER user throws ConflictException")
    void linkGoogleAccount_alreadyLinkedToAnotherUser_throwsConflict() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-link", "other@example.com", "Other User");
        User currentUser = buildSampleUser(1, "myuser", "myuser@example.com", UserStatus.ACTIVE);
        User otherUser = buildSampleUser(99, "otheruser", "other@example.com", UserStatus.ACTIVE);
        UserIdentity otherIdentity = UserIdentity.builder()
                .identityId(15)
                .user(otherUser)
                .provider("GOOGLE")
                .providerSubject("google-sub-link")
                .email("other@example.com")
                .build();

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userRepository.findByUsername("myuser")).thenReturn(Optional.of(currentUser));
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-link"))
                .thenReturn(Optional.of(otherIdentity));

        ConflictException ex = assertThrows(ConflictException.class,
                () -> googleAuthService.linkGoogleAccount("myuser", new GoogleLinkRequest(tokenStr)));
        assertTrue(ex.getMessage().contains("khác"));
        verify(userIdentityRepository, never()).save(any());
    }

    @Test
    @DisplayName("linkGoogleAccount: Current user already linked to a different Google account throws ConflictException")
    void linkGoogleAccount_userAlreadyHasAnotherGoogleAccount_throwsConflict() {
        String tokenStr = "valid.google.idtoken";
        GoogleUserInfo userInfo = buildSampleGoogleUserInfo("google-sub-new", "linkme2@example.com", "Link Me 2");
        User currentUser = buildSampleUser(1, "myuser", "myuser@example.com", UserStatus.ACTIVE);
        UserIdentity oldIdentity = UserIdentity.builder()
                .identityId(18)
                .user(currentUser)
                .provider("GOOGLE")
                .providerSubject("google-sub-old")
                .email("old@example.com")
                .build();

        when(googleTokenVerifier.verify(tokenStr)).thenReturn(userInfo);
        when(userRepository.findByUsername("myuser")).thenReturn(Optional.of(currentUser));
        when(userIdentityRepository.findByProviderAndProviderSubject("GOOGLE", "google-sub-new"))
                .thenReturn(Optional.empty());
        when(userIdentityRepository.findByUser_UserIdAndProvider(1, "GOOGLE"))
                .thenReturn(Optional.of(oldIdentity));

        ConflictException ex = assertThrows(ConflictException.class,
                () -> googleAuthService.linkGoogleAccount("myuser", new GoogleLinkRequest(tokenStr)));
        assertTrue(ex.getMessage().contains("đã được liên kết với một tài khoản Google khác"));
        verify(userIdentityRepository, never()).save(any());
    }
}
