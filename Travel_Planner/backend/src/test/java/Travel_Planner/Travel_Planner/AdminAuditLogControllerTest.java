package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
public class AdminAuditLogControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private MockMvc mockMvc;
    private String adminToken;
    private String userToken;
    private String runTag;

    private AuditLog log1SameTsLowerId;
    private AuditLog log2SameTsHigherId;
    private AuditLog log3FailedWithSecrets;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        long ts = System.currentTimeMillis();
        runTag = String.valueOf(ts);

        User adminUser = userRepository.save(User.builder()
                .username("audit_admin_" + ts)
                .email("audit_admin_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Audit Admin")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        User regularUser = userRepository.save(User.builder()
                .username("audit_user_" + ts)
                .email("audit_user_" + ts + "@test.com")
                .password(passwordEncoder.encode("Password@123"))
                .fullName("Audit Regular User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        adminToken = "Bearer " + jwtTokenProvider.generateToken(adminUser);
        userToken = "Bearer " + jwtTokenProvider.generateToken(regularUser);

        LocalDateTime sharedTimestamp = LocalDateTime.of(2025, 1, 20, 10, 0, 0);

        log1SameTsLowerId = auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(adminUser.getUserId())
                .actorUsername("alpha_" + runTag)
                .actionType(AuditActionType.USER_BAN)
                .targetType(AuditTargetType.USER)
                .targetId("201_" + runTag)
                .reason("Spam account")
                .resultStatus(AuditResultStatus.SUCCESS)
                .ipAddress("10.0.0.1")
                .correlationId("corr-101-" + runTag)
                .createdAt(sharedTimestamp)
                .build());

        log2SameTsHigherId = auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(adminUser.getUserId())
                .actorUsername("alpha_" + runTag)
                .actionType(AuditActionType.ITINERARY_MODERATE)
                .targetType(AuditTargetType.ITINERARY)
                .targetId("305_" + runTag)
                .reason("Policy violation")
                .resultStatus(AuditResultStatus.SUCCESS)
                .ipAddress("10.0.0.2")
                .correlationId("corr-202-" + runTag)
                .createdAt(sharedTimestamp)
                .build());

        log3FailedWithSecrets = auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(999)
                .actorUsername("beta_" + runTag)
                .actionType(AuditActionType.PLACE_ADMIN_AREA_LINK)
                .targetType(AuditTargetType.PLACE)
                .targetId("505_" + runTag)
                .reason("Manual area assignment")
                .resultStatus(AuditResultStatus.FAILED)
                .beforeDataJson("{\"email\":\"secret@example.com\",\"password\":\"SuperSecret123\",\"token\":\"eyJhbGciOiJIUzI1NiJ9.abcdefghij.klmnop\"}")
                .afterDataJson("{\"administrativeAreaCode\":\"00070\",\"apiKey\":\"raw-api-key-999\"}")
                .ipAddress("192.168.1.10")
                .userAgent("Mozilla/5.0")
                .correlationId("corr-303-" + runTag)
                .createdAt(LocalDateTime.of(2025, 1, 19, 8, 30, 0))
                .build());
    }

    @AfterEach
    void tearDown() {
        TestDatabaseCleaner.clean(jdbcTemplate);
    }

    @Test
    @DisplayName("RBAC: Unauthenticated (401) and non-ADMIN (403) must be rejected; ADMIN succeeds")
    void security_RbacEnforced() throws Exception {
        mockMvc.perform(get("/api/admin/audit-logs"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", userToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/audit-logs/" + log1SameTsLowerId.getLogId())
                        .header("Authorization", userToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("keyword", runTag)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements", is(3)));
    }

    @Test
    @DisplayName("Stable pagination: sorts by createdAt DESC then logId DESC without drift")
    void pagination_StableCompoundOrder() throws Exception {
        // Page 0, size 2 -> [log2SameTsHigherId, log1SameTsLowerId]
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("keyword", runTag)
                        .param("page", "0")
                        .param("size", "2")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.content[0].logId", is(log2SameTsHigherId.getLogId().intValue())))
                .andExpect(jsonPath("$.content[1].logId", is(log1SameTsLowerId.getLogId().intValue())))
                .andExpect(jsonPath("$.totalPages", is(2)))
                .andExpect(jsonPath("$.last", is(false)));

        // Page 1, size 2 -> [log3FailedWithSecrets]
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("keyword", runTag)
                        .param("page", "1")
                        .param("size", "2")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].logId", is(log3FailedWithSecrets.getLogId().intValue())))
                .andExpect(jsonPath("$.last", is(true)));

        // Invalid page/size validation
        mockMvc.perform(get("/api/admin/audit-logs?page=-1&size=20")
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/admin/audit-logs?page=0&size=101")
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Filtering: supports individual and combined filters and rejects invalid date range")
    void filters_IndividualCombinedAndDateValidation() throws Exception {
        // Filter by actionType + targetType + keyword(runTag)
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("keyword", runTag)
                        .param("actionType", "ITINERARY_MODERATE")
                        .param("targetType", "ITINERARY")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements", is(1)))
                .andExpect(jsonPath("$.content[0].logId", is(log2SameTsHigherId.getLogId().intValue())));

        // Filter by actorUsername + resultStatus + targetId
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("actorUsername", "beta_" + runTag)
                        .param("resultStatus", "FAILED")
                        .param("targetId", "505_" + runTag)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements", is(1)))
                .andExpect(jsonPath("$.content[0].logId", is(log3FailedWithSecrets.getLogId().intValue())));

        // Filter by keyword (correlationId)
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("keyword", "corr-101-" + runTag)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements", is(1)))
                .andExpect(jsonPath("$.content[0].logId", is(log1SameTsLowerId.getLogId().intValue())));

        // Filter by date range
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("keyword", runTag)
                        .param("fromDate", "2025-01-20")
                        .param("toDate", "2025-01-20")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements", is(2)));

        // Invalid date range: fromDate > toDate -> 400 Bad Request
        mockMvc.perform(get("/api/admin/audit-logs")
                        .param("fromDate", "2025-01-25")
                        .param("toDate", "2025-01-20")
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("Detail & Masking: masks sensitive snapshot fields and never exposes raw credentials")
    void detail_MasksSnapshotsAndDoesNotMutate() throws Exception {
        long countBefore = auditLogRepository.count();

        mockMvc.perform(get("/api/admin/audit-logs/" + log3FailedWithSecrets.getLogId())
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.logId", is(log3FailedWithSecrets.getLogId().intValue())))
                .andExpect(jsonPath("$.userAgent", is("Mozilla/5.0")))
                .andExpect(jsonPath("$.beforeDataJson", not(containsString("SuperSecret123"))))
                .andExpect(jsonPath("$.beforeDataJson", not(containsString("eyJhbGciOiJIUzI1NiJ9"))))
                .andExpect(jsonPath("$.beforeDataJson", containsString("***MASKED***")))
                .andExpect(jsonPath("$.afterDataJson", not(containsString("raw-api-key-999"))))
                .andExpect(jsonPath("$.afterDataJson", containsString("***MASKED***")))
                .andExpect(jsonPath("$.afterDataJson", containsString("00070")));

        // Verify querying never mutates audit_logs
        assertEquals(countBefore, auditLogRepository.count());
    }

    @Test
    @DisplayName("Immutability: no POST/PUT/PATCH/DELETE endpoints exist on /api/admin/audit-logs")
    void immutability_NoMutationEndpoints() throws Exception {
        long countBefore = auditLogRepository.count();

        mockMvc.perform(post("/api/admin/audit-logs")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isMethodNotAllowed());

        mockMvc.perform(put("/api/admin/audit-logs/" + log1SameTsLowerId.getLogId())
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isMethodNotAllowed());

        mockMvc.perform(patch("/api/admin/audit-logs/" + log1SameTsLowerId.getLogId())
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isMethodNotAllowed());

        mockMvc.perform(delete("/api/admin/audit-logs/" + log1SameTsLowerId.getLogId())
                        .header("Authorization", adminToken))
                .andExpect(status().isMethodNotAllowed());

        assertEquals(countBefore, auditLogRepository.count());
    }
}
