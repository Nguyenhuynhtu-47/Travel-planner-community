package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.GoogleAuthRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleLinkRequest;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserIdentity;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserIdentityRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.GoogleTokenVerifier;
import Travel_Planner.Travel_Planner.security.GoogleUserInfo;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class GoogleAuthControllerIntegrationTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserIdentityRepository userIdentityRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private GoogleTokenVerifier googleTokenVerifier;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders
                .webAppContextSetup(context)
                .apply(springSecurity())
                .build();
    }

    @AfterEach
    void tearDown() {
        // Clean up test identities and users
        userIdentityRepository.deleteAll();
        userRepository.findByEmail("google_it_new@example.com").ifPresent(userRepository::delete);
        userRepository.findByEmail("google_it_local@example.com").ifPresent(userRepository::delete);
        userRepository.findByEmail("google_it_linked@example.com").ifPresent(userRepository::delete);
        userRepository.findByEmail("google_it_other@example.com").ifPresent(userRepository::delete);
    }

    @Test
    @DisplayName("POST /api/auth/google: Missing idToken returns 400 Bad Request")
    void googleAuth_missingIdToken_returns400() throws Exception {
        GoogleAuthRequest request = new GoogleAuthRequest("");

        mockMvc.perform(post("/api/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("POST /api/auth/google: New Google user automatically registers and returns 200 with JWT")
    void googleAuth_newUser_returns200AndJwt() throws Exception {
        GoogleUserInfo userInfo = GoogleUserInfo.builder()
                .sub("sub-it-new-12345")
                .email("google_it_new@example.com")
                .emailVerified(true)
                .name("New Google User")
                .picture("https://example.com/avatar.png")
                .build();

        when(googleTokenVerifier.verify("token-it-new")).thenReturn(userInfo);

        GoogleAuthRequest request = new GoogleAuthRequest("token-it-new");

        mockMvc.perform(post("/api/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token", notNullValue()))
                .andExpect(jsonPath("$.tokenType", is("Bearer")))
                .andExpect(jsonPath("$.user.email", is("google_it_new@example.com")))
                .andExpect(jsonPath("$.user.emailVerified", is(true)));
    }

    @Test
    @DisplayName("POST /api/auth/google: Existing local email returns 409 Conflict (Anti-Account Hijacking)")
    void googleAuth_existingLocalAccount_returns409Conflict() throws Exception {
        // Pre-create local user
        User localUser = User.builder()
                .username("it_localuser")
                .handle("it_localuser")
                .email("google_it_local@example.com")
                .password(passwordEncoder.encode("LocalSecret123!"))
                .fullName("Local User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        userRepository.save(localUser);

        GoogleUserInfo userInfo = GoogleUserInfo.builder()
                .sub("sub-it-conflict-999")
                .email("google_it_local@example.com")
                .emailVerified(true)
                .name("Local Impersonator")
                .build();

        when(googleTokenVerifier.verify("token-it-conflict")).thenReturn(userInfo);

        GoogleAuthRequest request = new GoogleAuthRequest("token-it-conflict");

        mockMvc.perform(post("/api/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status", is(409)))
                .andExpect(jsonPath("$.message", containsString("liên kết")));
    }

    @Test
    @DisplayName("POST /api/auth/google: Existing linked user signs in successfully")
    void googleAuth_existingLinkedUser_returns200() throws Exception {
        User linkedUser = User.builder()
                .username("it_linkeduser")
                .handle("it_linkeduser")
                .email("google_it_linked@example.com")
                .password(passwordEncoder.encode("UnusablePassword123!"))
                .fullName("Linked User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        linkedUser = userRepository.save(linkedUser);

        UserIdentity identity = UserIdentity.builder()
                .user(linkedUser)
                .provider("GOOGLE")
                .providerSubject("sub-it-linked-777")
                .email("google_it_linked@example.com")
                .build();
        userIdentityRepository.save(identity);

        GoogleUserInfo userInfo = GoogleUserInfo.builder()
                .sub("sub-it-linked-777")
                .email("google_it_linked@example.com")
                .emailVerified(true)
                .name("Linked User")
                .build();

        when(googleTokenVerifier.verify("token-it-linked")).thenReturn(userInfo);

        GoogleAuthRequest request = new GoogleAuthRequest("token-it-linked");

        mockMvc.perform(post("/api/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token", notNullValue()))
                .andExpect(jsonPath("$.user.username", is("it_linkeduser")));
    }

    @Test
    @DisplayName("POST /api/auth/google/link: Unauthenticated call returns 401 Unauthorized")
    void googleLink_unauthenticated_returns401() throws Exception {
        GoogleLinkRequest request = new GoogleLinkRequest("some-token");

        mockMvc.perform(post("/api/auth/google/link")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("POST /api/auth/google/link: Authenticated call links Google account successfully")
    void googleLink_authenticated_returns200() throws Exception {
        User user = User.builder()
                .username("it_linktarget")
                .handle("it_linktarget")
                .email("google_it_local@example.com")
                .password(passwordEncoder.encode("LocalSecret123!"))
                .fullName("Link Target User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        user = userRepository.save(user);

        String jwt = jwtTokenProvider.generateToken(user);

        GoogleUserInfo userInfo = GoogleUserInfo.builder()
                .sub("sub-it-target-link")
                .email("google_it_local@example.com")
                .emailVerified(true)
                .name("Link Target User")
                .build();

        when(googleTokenVerifier.verify("token-link-target")).thenReturn(userInfo);

        GoogleLinkRequest request = new GoogleLinkRequest("token-link-target");

        mockMvc.perform(post("/api/auth/google/link")
                        .header("Authorization", "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.provider", is("GOOGLE")))
                .andExpect(jsonPath("$.linkedEmail", is("google_it_local@example.com")))
                .andExpect(jsonPath("$.message", containsString("thành công")));
    }
}
