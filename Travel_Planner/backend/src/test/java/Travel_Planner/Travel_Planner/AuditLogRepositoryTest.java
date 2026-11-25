package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.audit.UserAuditSnapshot;
import Travel_Planner.Travel_Planner.exception.AuditTrailPersistenceException;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.CustomUserDetails;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.impl.AuditLogServiceImpl;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.context.WebApplicationContext;

import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
class AuditLogRepositoryTest {

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private AuditLogService auditLogService;

    @Autowired
    private AuditLogServiceImpl auditLogServiceImpl;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private WebApplicationContext webApplicationContext;

    @PersistenceContext
    private EntityManager entityManager;

    private TransactionTemplate transactionTemplate;
    private MockMvc mockMvc;
    private User testAdmin;
    private User testTargetUser;

    @BeforeEach
    void setUp() {
        transactionTemplate = new TransactionTemplate(transactionManager);
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext)
                .apply(springSecurity())
                .build();

        jdbcTemplate.execute("DELETE FROM audit_logs");

        String suffix = UUID.randomUUID().toString().substring(0, 8);
        testAdmin = userRepository.save(User.builder()
                .username("audit_admin_" + suffix)
                .handle("auditadmin_" + suffix)
                .password("EncodedPwd#123")
                .email("audit_admin_" + suffix + "@example.com")
                .role(Role.ADMIN)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        testTargetUser = userRepository.save(User.builder()
                .username("audit_target_" + suffix)
                .handle("audittarget_" + suffix)
                .password("TargetSecretPwd#123")
                .email("audit_target_" + suffix + "@example.com")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        CustomUserDetails principal = new CustomUserDetails(
                testAdmin.getUserId(), testAdmin.getUsername(), testAdmin.getPassword(),
                testAdmin.getEmail(), 1, true, true,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
        jdbcTemplate.execute("DELETE FROM audit_logs");
        if (testTargetUser != null && testTargetUser.getUserId() != null) {
            try {
                userRepository.deleteById(testTargetUser.getUserId());
            } catch (Exception ignored) {}
        }
        if (testAdmin != null && testAdmin.getUserId() != null) {
            try {
                userRepository.deleteById(testAdmin.getUserId());
            } catch (Exception ignored) {}
        }
    }

    @Test
    @DisplayName("Strict Audit persists end-to-end to MySQL with accurate actor, action, target, timestamp, and masked snapshots")
    void strictAudit_persistsEndToEndToDatabase() {
        AuditLog saved = auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(AuditActionType.USER_BAN)
                .targetType(AuditTargetType.USER)
                .targetId(String.valueOf(testTargetUser.getUserId()))
                .reason("Confirmed spam behavior")
                .beforeSnapshot(UserAuditSnapshot.from(testTargetUser))
                .afterSnapshot(Map.of(
                        "userId", testTargetUser.getUserId(),
                        "status", "BANNED",
                        "nested", Map.of("token", "leaked_jwt_value", "secretKey", "abc")
                ))
                .build());

        assertNotNull(saved.getLogId());
        AuditLog fetched = auditLogRepository.findById(saved.getLogId()).orElseThrow();
        assertEquals(testAdmin.getUserId(), fetched.getActorId());
        assertEquals(testAdmin.getUsername(), fetched.getActorUsername());
        assertEquals(AuditActionType.USER_BAN, fetched.getActionType());
        assertEquals(AuditTargetType.USER, fetched.getTargetType());
        assertEquals(String.valueOf(testTargetUser.getUserId()), fetched.getTargetId());
        assertEquals(AuditResultStatus.SUCCESS, fetched.getResultStatus());
        assertNotNull(fetched.getCreatedAt());
        assertNotNull(fetched.getCorrelationId());
        assertFalse(fetched.getBeforeDataJson().contains("TargetSecretPwd#123"));
        assertFalse(fetched.getAfterDataJson().contains("leaked_jwt_value"));
        assertTrue(fetched.getAfterDataJson().contains("***MASKED***"));
    }

    @Test
    @DisplayName("Real transaction boundary: when Strict Audit fails, enclosing business DB mutation rolls back completely")
    void strictAudit_realTransactionBoundary_rollsBackBusinessChangeOnAuditFailure() {
        long initialAuditCount = auditLogRepository.count();
        String originalFullName = testTargetUser.getFullName();

        // Fail strict audit persistence via DB constraint / column truncation (> 50 chars targetType/etc or readOnly violation / > 10000 reason?):
        // Simulate an audit persistence failure inside the SAME physical REQUIRED transaction by passing an oversized action/reason
        // or forcing persistence failure with a null/invalid target column or DB exception inside tx.
        // Specifically: target_id VARCHAR(100) is truncated safely, whereas invoking strict audit inside readOnly=true
        // or failing DB check constraint rolls back the user update. Even stronger: test BOTH:
        // Case A: Outer business mutation executes, then AuditLog fails DB constraint (e.g. actorUsername > 50 or readOnly tx) -> user mutation MUST roll back!
        // Case B: AuditLog succeeds & flushes, then outer business mutation throws RuntimeException -> AuditLog MUST roll back!

        // Case B: AuditLog logs first, then business op throws RuntimeException -> both rollback
        assertThrows(IllegalStateException.class, () ->
                transactionTemplate.execute(status -> {
                    User target = userRepository.findById(testTargetUser.getUserId()).orElseThrow();
                    target.setFullName("Mutated Before Failure");
                    userRepository.saveAndFlush(target);

                    AuditLog entry = auditLogService.logStrictAction(AuditCommand.builder()
                            .actionType(AuditActionType.USER_BAN)
                            .targetType(AuditTargetType.USER)
                            .targetId(String.valueOf(target.getUserId()))
                            .reason("Should rollback with outer tx")
                            .build());
                    assertNotNull(entry.getLogId());

                    throw new IllegalStateException("Business step failed after audit flush");
                }));

        User reloadedAfterCaseB = userRepository.findById(testTargetUser.getUserId()).orElseThrow();
        assertEquals(originalFullName, reloadedAfterCaseB.getFullName());
        assertEquals(initialAuditCount, auditLogRepository.count());

        // Case A: Business mutation executes, then Strict Audit fails inside same transaction (e.g. AuditTrailPersistenceException triggered by failing DB insert)
        // We simulate a real DB insert failure by violating actor_username VARCHAR(50) NOT NULL or readOnly error inside REQUIRED tx.
        assertThrows(AuditTrailPersistenceException.class, () ->
                transactionTemplate.execute(status -> {
                    User target = userRepository.findById(testTargetUser.getUserId()).orElseThrow();
                    target.setFullName("Mutated Should Rollback");
                    userRepository.saveAndFlush(target);

                    // Force strict audit failure inside this transaction by swapping SecurityContext to unpersisted oversized username > 50 chars
                    // Wait: AuditContextResolver truncates username to 50 chars safely; instead trigger an authentic MySQL persistence error
                    // via malformed/too-long JSON or read-only synchronization check:
                    // Temporarily mark tx readOnly? No, MySQL won't flush user update if readOnly. Instead test direct DB persistence failure:
                    jdbcTemplate.execute("SET @audit_fail_check = 1");
                    // Pass an invalid snapshot that triggers DataAccessException on audit_logs or exceed TEXT?
                    // Actually, let's test via a failing Savepoint / constraint trigger or readOnly flag AFTER flush,
                    // OR even cleaner: verify that a real DataIntegrityViolationException inside audit_logs rolls back user update!
                    // Trigger DataIntegrityViolationException: pass reason with 4-byte emoji? utf8mb4 accepts emoji.
                    // What fails audit_logs INSERT in MySQL? Setting actor_id = null? Wait: CustomUserDetails rejects null.
                    // Use AuditLogServiceImpl with a failing mock AuditLogRepository? No, here we have real Spring proxy & DB!
                    // Even better: temporarily drop-and-restore? NO DDL in tests!
                    // Instead, invoke auditLogService.logStrictAction inside a transaction where targetUser update ran AND AuditCommand has a 65536+ char snapshot exceeding MySQL TEXT (65,535 bytes)!
                    String hugeValue = "x".repeat(70_000);
                    auditLogService.logStrictAction(AuditCommand.builder()
                            .actionType(AuditActionType.SETTING_UPDATE)
                            .targetType(AuditTargetType.SYSTEM_SETTING)
                            .targetId("HUGE_SETTING")
                            .afterSnapshot(Map.of("huge", hugeValue))
                            .build());
                    return null;
                }));

        User reloadedAfterCaseA = userRepository.findById(testTargetUser.getUserId()).orElseThrow();
        assertEquals(originalFullName, reloadedAfterCaseA.getFullName(),
                "Business user mutation MUST roll back when Strict Audit persistence fails in MySQL!");
        assertEquals(initialAuditCount, auditLogRepository.count(),
                "No partial audit row should exist after rollback!");
    }

    @Test
    @DisplayName("Best-effort telemetry failure does NOT roll back enclosing real MySQL business transaction")
    void bestEffortTelemetry_failureDoesNotRollbackBusinessTransaction() {
        String updatedFullName = "Committed Despite Telemetry Failure";
        auditLogServiceImpl.setTelemetryEmitter((actor, action, targetType, targetId, payload, corrId) -> {
            throw new RuntimeException("Simulated telemetry outage");
        });

        transactionTemplate.executeWithoutResult(status -> {
            User target = userRepository.findById(testTargetUser.getUserId()).orElseThrow();
            target.setFullName(updatedFullName);
            userRepository.saveAndFlush(target);

            auditLogService.recordBestEffortTelemetry(AuditCommand.builder()
                    .actionType(AuditActionType.TELEMETRY_OPERATIONAL)
                    .targetType(AuditTargetType.SYSTEM)
                    .targetId("probe_1")
                    .build());
        });

        User reloaded = userRepository.findById(testTargetUser.getUserId()).orElseThrow();
        assertEquals(updatedFullName, reloaded.getFullName());
    }

    @Test
    @DisplayName("Append-only invariant: Repository exposes zero delete/update methods and JPA entity blocks delete/update")
    void appendOnly_repositoryAndEntity_preventDeleteAndUpdate() {
        List<String> methodNames = Arrays.stream(AuditLogRepository.class.getMethods())
                .map(Method::getName)
                .toList();

        assertTrue(methodNames.stream().noneMatch(m -> m.startsWith("delete")),
                "AuditLogRepository must not expose any delete* methods");
        assertTrue(methodNames.stream().noneMatch(m -> m.startsWith("remove")),
                "AuditLogRepository must not expose any remove* methods");
        assertTrue(methodNames.stream().noneMatch(m -> m.startsWith("update")),
                "AuditLogRepository must not expose any update* methods");

        AuditLog saved = auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(AuditActionType.POST_PURGE)
                .targetType(AuditTargetType.POST)
                .targetId("999")
                .reason("Severe abuse")
                .build());

        assertThrows(UnsupportedOperationException.class, () ->
                transactionTemplate.executeWithoutResult(status -> {
                    AuditLog managed = entityManager.find(AuditLog.class, saved.getLogId());
                    entityManager.remove(managed);
                    entityManager.flush();
                }));

        // Verify persisted row remains completely intact
        assertTrue(auditLogRepository.existsById(saved.getLogId()));
        assertEquals(1L, auditLogRepository.count());
    }

    @Test
    @DisplayName("Stable pagination orders audit_logs deterministically by created_at DESC, log_id DESC")
    void stablePagination_ordersByCreatedAtDescLogIdDesc() {
        LocalDateTime sameTimestamp = LocalDateTime.of(2026, 11, 25, 10, 0, 0);

        AuditLog log1 = auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(testAdmin.getUserId()).actorUsername(testAdmin.getUsername())
                .actionType(AuditActionType.USER_BAN).targetType(AuditTargetType.USER)
                .targetId("1").resultStatus(AuditResultStatus.SUCCESS).createdAt(sameTimestamp).build());
        AuditLog log2 = auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(testAdmin.getUserId()).actorUsername(testAdmin.getUsername())
                .actionType(AuditActionType.USER_BAN).targetType(AuditTargetType.USER)
                .targetId("2").resultStatus(AuditResultStatus.SUCCESS).createdAt(sameTimestamp).build());
        AuditLog log3 = auditLogRepository.saveAndFlush(AuditLog.builder()
                .actorId(testAdmin.getUserId()).actorUsername(testAdmin.getUsername())
                .actionType(AuditActionType.USER_BAN).targetType(AuditTargetType.USER)
                .targetId("3").resultStatus(AuditResultStatus.SUCCESS).createdAt(sameTimestamp).build());

        Page<AuditLog> page0 = auditLogRepository.findByOrderByCreatedAtDescLogIdDesc(PageRequest.of(0, 2));
        Page<AuditLog> page1 = auditLogRepository.findByOrderByCreatedAtDescLogIdDesc(PageRequest.of(1, 2));

        assertEquals(2, page0.getContent().size());
        assertEquals(log3.getLogId(), page0.getContent().get(0).getLogId());
        assertEquals(log2.getLogId(), page0.getContent().get(1).getLogId());

        assertEquals(1, page1.getContent().size());
        assertEquals(log1.getLogId(), page1.getContent().get(0).getLogId());
    }

    @Test
    @DisplayName("Security guard: clients cannot forge or delete audit logs via public or admin HTTP endpoints")
    void securityBoundary_noPublicOrMutationAuditEndpointsExposed() throws Exception {
        SecurityContextHolder.clearContext();

        // Unauthenticated attempt to write to public or admin audit endpoint must fail (401/403/404)
        mockMvc.perform(post("/api/audit-logs")
                        .contentType("application/json")
                        .content("{\"actorId\":1,\"actionType\":\"USER_BAN\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/admin/audit-logs")
                        .contentType("application/json")
                        .content("{\"actorId\":1,\"actionType\":\"USER_BAN\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(delete("/api/admin/audit-logs/1"))
                .andExpect(status().isUnauthorized());

        // Authenticated regular USER also blocked with 403 on /api/admin/audit-logs/** and 404 on /api/audit-logs
        CustomUserDetails regularUser = new CustomUserDetails(
                testTargetUser.getUserId(), testTargetUser.getUsername(), testTargetUser.getPassword(),
                testTargetUser.getEmail(), 1, true, true,
                List.of(new SimpleGrantedAuthority("ROLE_USER")));
        UsernamePasswordAuthenticationToken userAuth =
                new UsernamePasswordAuthenticationToken(regularUser, null, regularUser.getAuthorities());

        mockMvc.perform(post("/api/admin/audit-logs")
                        .with(authentication(userAuth))
                        .contentType("application/json")
                        .content("{\"actorId\":1}"))
                .andExpect(status().isForbidden());

        mockMvc.perform(post("/api/audit-logs")
                        .with(authentication(userAuth))
                        .contentType("application/json")
                        .content("{\"actorId\":1}"))
                .andExpect(status().isNotFound());
    }
}
