package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdminItineraryMigrationRunner;
import Travel_Planner.Travel_Planner.dto.request.ModerateItineraryRequest;
import Travel_Planner.Travel_Planner.exception.AuditTrailPersistenceException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.reset;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class AdminItineraryControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository itineraryDayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private PostRepository postRepository;

    @Autowired
    private PostReportRepository postReportRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private AdminItineraryMigrationRunner adminItineraryMigrationRunner;

    @MockitoSpyBean
    private AuditLogService auditLogService;

    private MockMvc mockMvc;
    private User adminUser;
    private User regularUser;
    private String adminToken;
    private String userToken;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();
        reset(auditLogService);
        cleanDatabase();

        adminUser = saveUser("itin_admin_" + suffix(), Role.ADMIN, UserStatus.ACTIVE);
        regularUser = saveUser("itin_user_" + suffix(), Role.USER, UserStatus.ACTIVE);
        adminToken = jwtTokenProvider.generateToken(adminUser);
        userToken = jwtTokenProvider.generateToken(regularUser);
    }

    @AfterEach
    void tearDown() {
        reset(auditLogService);
        cleanDatabase();
    }

    private void cleanDatabase() {
        jdbcTemplate.execute("DELETE FROM audit_logs");
        jdbcTemplate.execute("DELETE FROM post_reports");
        jdbcTemplate.execute("DELETE FROM posts");
        jdbcTemplate.execute("DELETE FROM activities");
        jdbcTemplate.execute("DELETE FROM itinerary_days");
        jdbcTemplate.execute("DELETE FROM itineraries");
        jdbcTemplate.execute("DELETE FROM user_sessions");
        jdbcTemplate.execute("DELETE FROM users");
    }

    private String suffix() {
        return UUID.randomUUID().toString().substring(0, 8);
    }

    private User saveUser(String username, Role role, UserStatus status) {
        User u = User.builder()
                .username(username)
                .handle(username)
                .email(username + "@test.vn")
                .password("$2a$10$dummyhashedpasswordvalue12345678901234567890")
                .fullName("Full " + username)
                .role(role)
                .status(status)
                .emailVerified(true)
                .tokenVersion(1)
                .build();
        return userRepository.saveAndFlush(u);
    }

    private Itinerary saveItineraryWithDayAndActivity(
            User owner,
            String title,
            String location,
            Visibility visibility,
            ItineraryStatus status) {
        Itinerary itinerary = Itinerary.builder()
                .user(owner)
                .title(title)
                .description("Description for " + title)
                .location(location)
                .totalDays(2)
                .budget(new BigDecimal("2500000"))
                .theme("Khám phá")
                .visibility(visibility)
                .status(status)
                .viewCount(15)
                .build();
        itinerary = itineraryRepository.saveAndFlush(itinerary);

        ItineraryDay day = ItineraryDay.builder()
                .itinerary(itinerary)
                .dayNumber(1)
                .title("Ngày 1 tại " + location)
                .build();
        day = itineraryDayRepository.saveAndFlush(day);

        Activity activity = Activity.builder()
                .itineraryDay(day)
                .name("Secret Activity " + title)
                .description("Activity detail")
                .startTime(LocalTime.of(9, 0))
                .endTime(LocalTime.of(11, 0))
                .cost(new BigDecimal("150000"))
                .displayOrder(1)
                .locationName("Địa điểm " + location)
                .build();
        activityRepository.saveAndFlush(activity);
        return itinerary;
    }

    private PostReport saveReportForItinerary(Itinerary itinerary, ReportStatus reportStatus) {
        Post post = Post.builder()
                .author(itinerary.getUser())
                .itinerary(itinerary)
                .content("Bài viết chia sẻ lịch trình")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .build();
        post = postRepository.saveAndFlush(post);

        PostReport report = PostReport.builder()
                .post(post)
                .reporter(adminUser)
                .reason("SPAM_OR_INAPPROPRIATE")
                .details("Báo cáo cần thanh tra nội dung lịch trình")
                .status(reportStatus)
                .build();
        return postReportRepository.saveAndFlush(report);
    }

    @Test
    @DisplayName("Non-ADMIN and anonymous callers are rejected on all Admin Itinerary endpoints")
    void security_nonAdminAndAnonymous_rejected() throws Exception {
        Itinerary pub = saveItineraryWithDayAndActivity(
                regularUser, "Public Trip", "Đà Lạt", Visibility.PUBLIC, ItineraryStatus.ACTIVE);

        mockMvc.perform(get("/api/admin/itineraries"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/admin/itineraries")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/itineraries/" + pub.getItineraryId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden());

        ModerateItineraryRequest req = ModerateItineraryRequest.builder()
                .status(ItineraryStatus.HIDDEN)
                .reason("Vi phạm tiêu chuẩn cộng đồng")
                .build();
        mockMvc.perform(patch("/api/admin/itineraries/" + pub.getItineraryId() + "/moderate")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("List endpoint returns only PUBLIC itineraries, supports keyword/status/pagination, and rejects PRIVATE listing")
    void listAndFilter_returnsPublicOnly_andRejectsPrivateList() throws Exception {
        saveItineraryWithDayAndActivity(regularUser, "Chuyến đi Đà Lạt", "Đà Lạt", Visibility.PUBLIC, ItineraryStatus.ACTIVE);
        saveItineraryWithDayAndActivity(regularUser, "Lịch trình bị ẩn", "Nha Trang", Visibility.PUBLIC, ItineraryStatus.HIDDEN);
        saveItineraryWithDayAndActivity(regularUser, "Lịch trình đã xóa", "Huế", Visibility.PUBLIC, ItineraryStatus.DELETED);
        saveItineraryWithDayAndActivity(regularUser, "Chuyến đi bí mật PRIVATE", "Phú Quốc", Visibility.PRIVATE, ItineraryStatus.ACTIVE);

        mockMvc.perform(get("/api/admin/itineraries")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("page", "0")
                        .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content[*].title", hasItems("Chuyến đi Đà Lạt", "Lịch trình bị ẩn")))
                .andExpect(jsonPath("$.content[*].title", not(hasItem("Chuyến đi bí mật PRIVATE"))))
                .andExpect(jsonPath("$.content[*].title", not(hasItem("Lịch trình đã xóa"))));

        mockMvc.perform(get("/api/admin/itineraries")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("keyword", "Đà Lạt")
                        .param("status", "ACTIVE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Chuyến đi Đà Lạt"));

        mockMvc.perform(get("/api/admin/itineraries")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("visibility", "PRIVATE"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Public itinerary detail returns read-only days and activities without modifying viewCount")
    void publicDetail_returnsReadOnlyDetails() throws Exception {
        Itinerary pub = saveItineraryWithDayAndActivity(
                regularUser, "Khám phá Hội An", "Hội An", Visibility.PUBLIC, ItineraryStatus.ACTIVE);

        mockMvc.perform(get("/api/admin/itineraries/" + pub.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.itineraryId").value(pub.getItineraryId()))
                .andExpect(jsonPath("$.title").value("Khám phá Hội An"))
                .andExpect(jsonPath("$.privateInspection").value(false))
                .andExpect(jsonPath("$.days", hasSize(1)))
                .andExpect(jsonPath("$.days[0].activities", hasSize(1)));

        Itinerary reloaded = itineraryRepository.findById(pub.getItineraryId()).orElseThrow();
        assertEquals(15, reloaded.getViewCount());
        assertEquals(0, auditLogRepository.count());
    }

    @Test
    @DisplayName("Hide and restore itinerary enforce reason validation and persist Strict Audit")
    void moderateItinerary_hideAndRestore_successAndValidation() throws Exception {
        Itinerary pub = saveItineraryWithDayAndActivity(
                regularUser, "Lịch trình cần duyệt", "Sapa", Visibility.PUBLIC, ItineraryStatus.ACTIVE);

        ModerateItineraryRequest invalidReason = ModerateItineraryRequest.builder()
                .status(ItineraryStatus.HIDDEN)
                .reason("ab")
                .build();
        mockMvc.perform(patch("/api/admin/itineraries/" + pub.getItineraryId() + "/moderate")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidReason)))
                .andExpect(status().isBadRequest());

        ModerateItineraryRequest deleteAttempt = ModerateItineraryRequest.builder()
                .status(ItineraryStatus.DELETED)
                .reason("Không được phép xóa vật lý")
                .build();
        mockMvc.perform(patch("/api/admin/itineraries/" + pub.getItineraryId() + "/moderate")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(deleteAttempt)))
                .andExpect(status().isBadRequest());

        ModerateItineraryRequest hideReq = ModerateItineraryRequest.builder()
                .status(ItineraryStatus.HIDDEN)
                .reason("Chứa liên kết quảng cáo spam")
                .build();
        mockMvc.perform(patch("/api/admin/itineraries/" + pub.getItineraryId() + "/moderate")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(hideReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HIDDEN"));

        assertEquals(ItineraryStatus.HIDDEN, itineraryRepository.findById(pub.getItineraryId()).orElseThrow().getStatus());

        ModerateItineraryRequest restoreReq = ModerateItineraryRequest.builder()
                .status(ItineraryStatus.ACTIVE)
                .reason("Người dùng đã chỉnh sửa đúng quy định")
                .build();
        mockMvc.perform(patch("/api/admin/itineraries/" + pub.getItineraryId() + "/moderate")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(restoreReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"));

        Itinerary restored = itineraryRepository.findById(pub.getItineraryId()).orElseThrow();
        assertEquals(ItineraryStatus.ACTIVE, restored.getStatus());
        assertEquals(regularUser.getUserId(), restored.getUser().getUserId());

        List<AuditLog> logs = auditLogRepository.findAll();
        assertEquals(2, logs.size());
        assertTrue(logs.stream().allMatch(l -> l.getActionType() == AuditActionType.ITINERARY_MODERATE));
    }

    @Test
    @DisplayName("Strict Audit failure rolls back itinerary moderation status change atomically")
    void moderateItinerary_whenAuditFails_rollsBackStatus() throws Exception {
        Itinerary pub = saveItineraryWithDayAndActivity(
                regularUser, "Rollback Trip", "Đà Nẵng", Visibility.PUBLIC, ItineraryStatus.ACTIVE);

        doThrow(new AuditTrailPersistenceException("Simulated audit DB failure"))
                .when(auditLogService).logStrictAction(any());

        ModerateItineraryRequest hideReq = ModerateItineraryRequest.builder()
                .status(ItineraryStatus.HIDDEN)
                .reason("Vi phạm nội dung cộng đồng")
                .build();
        mockMvc.perform(patch("/api/admin/itineraries/" + pub.getItineraryId() + "/moderate")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(hideReq)))
                .andExpect(status().isInternalServerError());

        Itinerary unchanged = itineraryRepository.findById(pub.getItineraryId()).orElseThrow();
        assertEquals(ItineraryStatus.ACTIVE, unchanged.getStatus());
    }

    @Test
    @DisplayName("PRIVATE itinerary inspection enforces valid PENDING report + reason >= 10 chars and writes Strict Audit")
    void privateInspection_enforcesReportAndReason_andLogsStrictAudit() throws Exception {
        Itinerary priv = saveItineraryWithDayAndActivity(
                regularUser, "Kế hoạch PRIVATE nhạy cảm", "Cần Thơ", Visibility.PRIVATE, ItineraryStatus.ACTIVE);
        Itinerary other = saveItineraryWithDayAndActivity(
                regularUser, "Lịch trình khác", "Vũng Tàu", Visibility.PUBLIC, ItineraryStatus.ACTIVE);

        PostReport pendingLinked = saveReportForItinerary(priv, ReportStatus.PENDING);
        PostReport resolvedLinked = saveReportForItinerary(priv, ReportStatus.RESOLVED);
        PostReport pendingOther = saveReportForItinerary(other, ReportStatus.PENDING);

        // 1. Missing reportId -> 403
        mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isForbidden());

        // 2. Non-existent reportId -> 403
        mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reportId", "999999")
                        .param("inspectionReason", "Kiểm tra báo cáo vi phạm hợp lệ"))
                .andExpect(status().isForbidden());

        // 3. Non-PENDING report -> 403
        mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reportId", String.valueOf(resolvedLinked.getReportId()))
                        .param("inspectionReason", "Kiểm tra báo cáo vi phạm hợp lệ"))
                .andExpect(status().isForbidden());

        // 4. Mismatched report -> 403
        mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reportId", String.valueOf(pendingOther.getReportId()))
                        .param("inspectionReason", "Kiểm tra báo cáo vi phạm hợp lệ"))
                .andExpect(status().isForbidden());

        // 5. Short inspectionReason -> 400
        mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reportId", String.valueOf(pendingLinked.getReportId()))
                        .param("inspectionReason", "Ngắn"))
                .andExpect(status().isBadRequest());

        assertEquals(0, auditLogRepository.count());

        // 6. Valid PENDING report + valid reason -> 200 + Strict Audit + read-only preserved
        mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reportId", String.valueOf(pendingLinked.getReportId()))
                        .param("inspectionReason", "Kiểm tra báo cáo spam đính kèm lịch trình riêng tư"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.privateInspection").value(true))
                .andExpect(jsonPath("$.inspectedReportId").value(pendingLinked.getReportId()))
                .andExpect(jsonPath("$.title").value("Kế hoạch PRIVATE nhạy cảm"))
                .andExpect(jsonPath("$.days[0].activities[0].name").value("Secret Activity Kế hoạch PRIVATE nhạy cảm"));

        List<AuditLog> logs = auditLogRepository.findAll();
        assertEquals(1, logs.size());
        assertEquals(AuditActionType.ITINERARY_PRIVATE_INSPECT, logs.get(0).getActionType());
        assertEquals(AuditTargetType.ITINERARY, logs.get(0).getTargetType());
        assertEquals(String.valueOf(priv.getItineraryId()), logs.get(0).getTargetId());

        Itinerary afterInspect = itineraryRepository.findById(priv.getItineraryId()).orElseThrow();
        assertEquals(Visibility.PRIVATE, afterInspect.getVisibility());
        assertEquals(ItineraryStatus.ACTIVE, afterInspect.getStatus());
        assertEquals(15, afterInspect.getViewCount());
    }

    @Test
    @DisplayName("PRIVATE inspection returns 500 and NEVER returns payload when Strict Audit fails")
    void privateInspection_whenAuditFails_neverLeaksPayload() throws Exception {
        Itinerary priv = saveItineraryWithDayAndActivity(
                regularUser, "TOP_SECRET_PRIVATE_TRIP_XYZ", "Hà Giang", Visibility.PRIVATE, ItineraryStatus.ACTIVE);
        PostReport pendingLinked = saveReportForItinerary(priv, ReportStatus.PENDING);

        doThrow(new AuditTrailPersistenceException("Audit write failed"))
                .when(auditLogService).logStrictAction(any());

        MvcResult result = mockMvc.perform(get("/api/admin/itineraries/" + priv.getItineraryId())
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reportId", String.valueOf(pendingLinked.getReportId()))
                        .param("inspectionReason", "Thanh tra lịch trình riêng tư theo báo cáo"))
                .andExpect(status().isInternalServerError())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        assertFalse(responseBody.contains("TOP_SECRET_PRIVATE_TRIP_XYZ"));
        assertFalse(responseBody.contains("Secret Activity"));
    }

    @Test
    @DisplayName("AdminItineraryMigrationRunner creates idx_itineraries_admin_query idempotently")
    void migrationRunner_isIdempotent() {
        adminItineraryMigrationRunner.ensureSchemaAndMigration();
        adminItineraryMigrationRunner.ensureSchemaAndMigration();

        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.statistics " +
                        "WHERE table_schema = DATABASE() AND table_name = 'itineraries' " +
                        "AND index_name = 'idx_itineraries_admin_query'",
                Integer.class);
        assertNotNull(count);
        assertTrue(count >= 1);
    }
}
