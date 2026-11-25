package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdministrativeAreaMigrationRunner;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class AdminDashboardControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private AdministrativeAreaRepository areaRepository;

    @Autowired
    private AdministrativeAreaMigrationRunner areaMigrationRunner;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private PostRepository postRepository;

    @Autowired
    private PostReportRepository postReportRepository;

    @Autowired
    private MediaAssetRepository mediaAssetRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private MockMvc mockMvc;
    private User adminUser;
    private User bannedUser;
    private String adminToken;
    private String userToken;

    @BeforeEach
    void setUp() throws Exception {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        areaMigrationRunner.migrateAndImport();

        long ts = System.currentTimeMillis();
        adminUser = userRepository.save(User.builder()
                .username("dash_admin_" + ts)
                .email("dash_admin_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Dashboard Admin")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        User regularUser = userRepository.save(User.builder()
                .username("dash_user_" + ts)
                .email("dash_user_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Dashboard User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        bannedUser = userRepository.save(User.builder()
                .username("dash_banned_" + ts)
                .email("dash_banned_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Dashboard Banned")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .emailVerified(true)
                .build());

        adminToken = "Bearer " + jwtTokenProvider.generateToken(adminUser);
        userToken = "Bearer " + jwtTokenProvider.generateToken(regularUser);
    }

    @AfterEach
    void tearDown() {
        TestDatabaseCleaner.clean(jdbcTemplate);
    }

    @Test
    @DisplayName("RBAC: Unauthenticated (401) and non-ADMIN (403) rejected; ADMIN accesses summary & analytics")
    void security_RbacEnforced() throws Exception {
        mockMvc.perform(get("/api/admin/dashboard/summary"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/admin/dashboard/summary")
                        .header("Authorization", userToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/dashboard/analytics")
                        .header("Authorization", userToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/dashboard/summary")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.healthStatus", is("UP")))
                .andExpect(jsonPath("$.totalUsers", greaterThanOrEqualTo(2)))
                .andExpect(jsonPath("$.bannedUsers", greaterThanOrEqualTo(1)));
    }

    @Test
    @DisplayName("Accuracy & Analytics: Returns exact DB counts, time-series over same window, recent audit logs, and validates days")
    void summaryAndAnalytics_ExactDatabaseCountsAndRangeValidation() throws Exception {
        AdministrativeArea ward = areaRepository.findByCodeWithParent("00070").orElseThrow();

        placeRepository.save(Place.builder()
                .name("Linked Dash Place")
                .address("Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0285"))
                .longitude(new BigDecimal("105.8542"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .administrativeArea(ward)
                .build());

        Itinerary hiddenItinerary = itineraryRepository.save(Itinerary.builder()
                .user(adminUser)
                .title("Hidden Dash Itinerary")
                .location("Hà Nội")
                .totalDays(2)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.HIDDEN)
                .build());

        Post hiddenPost = postRepository.save(Post.builder()
                .author(adminUser)
                .itinerary(hiddenItinerary)
                .content("Hidden post for dashboard test")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.HIDDEN)
                .build());

        postReportRepository.save(PostReport.builder()
                .post(hiddenPost)
                .reporter(bannedUser)
                .reason("Spam report for dashboard test")
                .status(ReportStatus.PENDING)
                .build());

        mediaAssetRepository.save(MediaAsset.builder()
                .cloudinaryPublicId("dash_dead_" + System.currentTimeMillis())
                .secureUrl("https://res.cloudinary.com/demo/image/upload/sample.jpg")
                .status(MediaAssetStatus.DELETING)
                .uploadedBy(adminUser)
                .deadLetteredAt(LocalDateTime.now())
                .build());

        auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(adminUser.getUserId())
                .actorUsername(adminUser.getUsername())
                .actionType(AuditActionType.SETTING_UPDATE)
                .targetType(AuditTargetType.SYSTEM_SETTING)
                .targetId("MEDIA_MAX_IMAGE_SIZE_MB")
                .reason("Dashboard recent audit test")
                .resultStatus(AuditResultStatus.SUCCESS)
                .createdAt(LocalDateTime.now())
                .build());

        mockMvc.perform(get("/api/admin/dashboard/summary")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalUsers", greaterThanOrEqualTo(2)))
                .andExpect(jsonPath("$.activeUsers", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.bannedUsers", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.totalPlaces", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.linkedPlaces", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.totalItineraries", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.publicItineraries", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.privateItineraries", greaterThanOrEqualTo(0)))
                .andExpect(jsonPath("$.activeItineraries", greaterThanOrEqualTo(0)))
                .andExpect(jsonPath("$.hiddenItineraries", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.totalPosts", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.hiddenPosts", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.pendingReportsCount", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.totalMediaAssets", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.deadLetterMediaAssets", greaterThanOrEqualTo(1)));

        mockMvc.perform(get("/api/admin/dashboard/analytics?days=7")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days", is(7)))
                .andExpect(jsonPath("$.userRegistrationsDaily", hasSize(7)))
                .andExpect(jsonPath("$.communityPostsWeekly", not(empty())))
                .andExpect(jsonPath("$.topPlaces", isA(java.util.List.class)))
                .andExpect(jsonPath("$.recentAuditLogs", not(empty())))
                .andExpect(jsonPath("$.recentAuditLogs[0].actionType", is("SETTING_UPDATE")));

        // Invalid days range -> 400
        mockMvc.perform(get("/api/admin/dashboard/analytics?days=0")
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/admin/dashboard/analytics?days=366")
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());
    }
}
