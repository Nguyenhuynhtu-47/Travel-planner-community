package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.AdminUserMigrationRunner;
import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserRoleRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.exception.AuditTrailPersistenceException;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserSession;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserSessionStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.UserSessionRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.UserSessionService;
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
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.reset;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
class AdminUserControllerTest {

    @Autowired
    private WebApplicationContext context;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserSessionRepository userSessionRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private UserSessionService userSessionService;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private AdminUserMigrationRunner adminUserMigrationRunner;

    @MockitoSpyBean
    private AuditLogService auditLogService;

    private MockMvc mockMvc;
    private User adminUser;
    private User regularUser;
    private User bannedUser;
    private String adminJwt;
    private String regularUserJwt;

    @BeforeEach
    void setUp() {
        reset(auditLogService);
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        jdbcTemplate.execute("DELETE FROM audit_logs");

        String suffix = UUID.randomUUID().toString().substring(0, 8);
        adminUser = userRepository.saveAndFlush(User.builder()
                .username("adm_ctrl_" + suffix)
                .handle("admctrl_" + suffix)
                .password("EncodedPass#1")
                .email("adm_ctrl_" + suffix + "@example.com")
                .fullName("Admin Controller Test")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        regularUser = userRepository.saveAndFlush(User.builder()
                .username("usr_ctrl_" + suffix)
                .handle("usrctrl_" + suffix)
                .password("EncodedPass#2")
                .email("usr_ctrl_" + suffix + "@example.com")
                .fullName("Nguyen Van Regular")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        bannedUser = userRepository.saveAndFlush(User.builder()
                .username("ban_ctrl_" + suffix)
                .handle("banctrl_" + suffix)
                .password("EncodedPass#3")
                .email("ban_ctrl_" + suffix + "@example.com")
                .fullName("Banned Sample")
                .role(Role.USER)
                .status(UserStatus.BANNED)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        UserSession adminSession = userSessionService.createSession(adminUser, "Chrome Web", "127.0.0.1", 86400000L);
        adminJwt = jwtTokenProvider.generateToken(adminUser, adminSession.getSessionId());

        UserSession userSession = userSessionService.createSession(regularUser, "Mobile App", "127.0.0.1", 86400000L);
        regularUserJwt = jwtTokenProvider.generateToken(regularUser, userSession.getSessionId());
    }

    @AfterEach
    void tearDown() {
        reset(auditLogService);
        jdbcTemplate.execute("DELETE FROM audit_logs");
        for (User u : List.of(adminUser, regularUser, bannedUser)) {
            if (u != null && u.getUserId() != null) {
                try {
                    jdbcTemplate.update("DELETE FROM user_sessions WHERE user_id = ?", u.getUserId());
                    userRepository.deleteById(u.getUserId());
                } catch (Exception ignored) {}
            }
        }
    }

    @Test
    @DisplayName("Phase 2 migration runner ensures admin_role_guard, ADMIN_ROLE_MUTEX, and idx_users_admin_filter")
    void migrationRunner_schemaComplete() throws Exception {
        try (Connection conn = dataSource.getConnection()) {
            assertTrue(adminUserMigrationRunner.isSchemaComplete(conn));
        }
    }

    @Test
    @DisplayName("Unauthenticated requests return 401 and ROLE_USER requests return 403 on all /api/admin/users endpoints")
    void rbac_blocksUnauthenticatedAndRegularUsers() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/admin/users")
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/users/" + adminUser.getUserId())
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/admin/users/" + bannedUser.getUserId() + "/status")
                        .header("Authorization", "Bearer " + regularUserJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateUserStatusRequest(UserStatus.ACTIVE, "Bypass try"))))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/admin/users/" + regularUser.getUserId() + "/role")
                        .header("Authorization", "Bearer " + regularUserJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpdateUserRoleRequest(Role.ADMIN, "Self elevate try"))))
                .andExpect(status().isForbidden());

        mockMvc.perform(post("/api/admin/users/" + regularUser.getUserId() + "/sessions/revoke-all")
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Admin GET /api/admin/users supports keyword, role, status filters, pagination, and never leaks secrets")
    void getUsers_admin_supportsFiltersAndHidesSensitiveFields() throws Exception {
        String body = mockMvc.perform(get("/api/admin/users")
                        .param("keyword", "Nguyen Van Regular")
                        .param("role", "USER")
                        .param("status", "ACTIVE")
                        .param("page", "0")
                        .param("size", "10")
                        .header("Authorization", "Bearer " + adminJwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].userId").value(regularUser.getUserId()))
                .andExpect(jsonPath("$.content[0].username").value(regularUser.getUsername()))
                .andExpect(jsonPath("$.content[0].role").value("USER"))
                .andExpect(jsonPath("$.content[0].status").value("ACTIVE"))
                .andReturn().getResponse().getContentAsString();

        assertFalse(body.contains("password"));
        assertFalse(body.contains("EncodedPass#2"));
        assertFalse(body.contains("tokenVersion"));
    }

    @Test
    @DisplayName("Admin GET /api/admin/users/{id} returns user detail and session list")
    void getUserDetail_admin_returnsDetailAndSessions() throws Exception {
        mockMvc.perform(get("/api/admin/users/" + regularUser.getUserId())
                        .header("Authorization", "Bearer " + adminJwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(regularUser.getUserId()))
                .andExpect(jsonPath("$.activeSessionCount").value(1))
                .andExpect(jsonPath("$.sessions.length()").value(1))
                .andExpect(jsonPath("$.sessions[0].deviceInfo").value("Mobile App"));
    }

    @Test
    @DisplayName("Ban revokes sessions + invalidates existing JWT immediately + writes Strict Audit; Unban restores ACTIVE")
    void banAndUnban_revokesJwtAndRecordsStrictAudit() throws Exception {
        // Verify regularUser JWT currently works on /api/user/profile
        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isOk());

        // BAN regularUser
        mockMvc.perform(patch("/api/admin/users/" + regularUser.getUserId() + "/status")
                        .header("Authorization", "Bearer " + adminJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new UpdateUserStatusRequest(UserStatus.BANNED, "Phát tán nội dung spam"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("BANNED"));

        // Old JWT must now be rejected immediately with 401
        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isUnauthorized());

        User reloaded = userRepository.findById(regularUser.getUserId()).orElseThrow();
        assertEquals(UserStatus.BANNED, reloaded.getStatus());
        assertEquals(2, reloaded.getTokenVersion());
        assertTrue(userSessionRepository.findByUser_UserIdOrderByCreatedAtDesc(regularUser.getUserId())
                .stream().allMatch(s -> s.getStatus() == UserSessionStatus.REVOKED));

        // UNBAN regularUser
        mockMvc.perform(patch("/api/admin/users/" + regularUser.getUserId() + "/status")
                        .header("Authorization", "Bearer " + adminJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new UpdateUserStatusRequest(UserStatus.ACTIVE, "Đã xác minh khiếu nại hợp lệ"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"));

        List<AuditLog> logs = auditLogRepository.findAll();
        assertEquals(2, logs.size());
        assertEquals(AuditActionType.USER_BAN, logs.get(0).getActionType());
        assertEquals(AuditActionType.USER_UNBAN, logs.get(1).getActionType());
        assertFalse(logs.get(0).getBeforeDataJson().contains("EncodedPass#2"));
        assertTrue(logs.get(0).getAfterDataJson().contains("BANNED"));
    }

    @Test
    @DisplayName("Promote & Demote update role, revoke active JWT sessions, and persist Strict Audit")
    void promoteAndDemote_revokesSessionsAndRecordsAudit() throws Exception {
        // Promote USER -> ADMIN
        mockMvc.perform(patch("/api/admin/users/" + regularUser.getUserId() + "/role")
                        .header("Authorization", "Bearer " + adminJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new UpdateUserRoleRequest(Role.ADMIN, "Bổ nhiệm điều phối viên"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("ADMIN"));

        // Existing USER JWT invalidated on role change
        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isUnauthorized());

        // Demote ADMIN -> USER
        mockMvc.perform(patch("/api/admin/users/" + regularUser.getUserId() + "/role")
                        .header("Authorization", "Bearer " + adminJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new UpdateUserRoleRequest(Role.USER, "Kết thúc nhiệm kỳ quản trị"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("USER"));

        List<AuditLog> logs = auditLogRepository.findAll();
        assertEquals(2, logs.size());
        assertEquals(AuditActionType.USER_ROLE_CHANGE, logs.get(0).getActionType());
        assertEquals(AuditActionType.USER_ROLE_CHANGE, logs.get(1).getActionType());
    }

    @Test
    @DisplayName("POST /api/admin/users/{id}/sessions/revoke-all invalidates target JWT and writes Strict Audit")
    void revokeSessions_endpoint_invalidatesJwtAndAudits() throws Exception {
        mockMvc.perform(post("/api/admin/users/" + regularUser.getUserId() + "/sessions/revoke-all")
                        .param("reason", "Phát hiện đăng nhập bất thường")
                        .header("Authorization", "Bearer " + adminJwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.revokedCount").value(1));

        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", "Bearer " + regularUserJwt))
                .andExpect(status().isUnauthorized());

        List<AuditLog> logs = auditLogRepository.findAll();
        assertEquals(1, logs.size());
        assertEquals(AuditActionType.USER_SESSIONS_REVOKE, logs.get(0).getActionType());
    }

    @Test
    @DisplayName("When Strict Audit fails, entire BAN transaction (user status, tokenVersion, sessions) rolls back")
    void strictAuditFailure_rollsBackUserStatusAndSessionRevocation() throws Exception {
        doThrow(new AuditTrailPersistenceException("Simulated audit DB failure"))
                .when(auditLogService).logStrictAction(any(AuditCommand.class));

        mockMvc.perform(patch("/api/admin/users/" + regularUser.getUserId() + "/status")
                        .header("Authorization", "Bearer " + adminJwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new UpdateUserStatusRequest(UserStatus.BANNED, "Must rollback cleanly"))))
                .andExpect(status().isInternalServerError());

        User reloaded = userRepository.findById(regularUser.getUserId()).orElseThrow();
        assertEquals(UserStatus.ACTIVE, reloaded.getStatus(), "User status MUST roll back to ACTIVE");
        assertEquals(1, reloaded.getTokenVersion(), "tokenVersion MUST roll back to 1");
        assertTrue(userSessionRepository.findByUser_UserIdOrderByCreatedAtDesc(regularUser.getUserId())
                .stream().allMatch(s -> s.getStatus() == UserSessionStatus.ACTIVE),
                "UserSession status MUST roll back to ACTIVE");
        assertEquals(0L, auditLogRepository.count());
    }
}
