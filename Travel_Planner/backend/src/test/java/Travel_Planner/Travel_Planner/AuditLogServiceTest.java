package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.audit.UserAuditSnapshot;
import Travel_Planner.Travel_Planner.exception.AuditTrailPersistenceException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.ClientIpResolver;
import Travel_Planner.Travel_Planner.security.CustomUserDetails;
import Travel_Planner.Travel_Planner.service.impl.AuditLogServiceImpl;
import Travel_Planner.Travel_Planner.util.AuditContextResolver;
import Travel_Planner.Travel_Planner.util.DataMaskingUtil;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuditLogServiceTest {

    private AuditLogRepository auditLogRepository;
    private UserRepository userRepository;
    private DataMaskingUtil dataMaskingUtil;
    private AuditContextResolver auditContextResolver;
    private AuditLogServiceImpl auditLogService;

    @BeforeEach
    void setUp() {
        auditLogRepository = mock(AuditLogRepository.class);
        userRepository = mock(UserRepository.class);
        dataMaskingUtil = new DataMaskingUtil();
        ClientIpResolver clientIpResolver = new ClientIpResolver("127.0.0.1");
        auditContextResolver = new AuditContextResolver(userRepository, clientIpResolver);
        auditLogService = new AuditLogServiceImpl(auditLogRepository, dataMaskingUtil, auditContextResolver);

        when(auditLogRepository.saveAndFlush(any(AuditLog.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
        RequestContextHolder.resetRequestAttributes();
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
        TransactionSynchronizationManager.setCurrentTransactionReadOnly(false);
    }

    private void authenticateAdmin(Integer userId, String username) {
        CustomUserDetails principal = new CustomUserDetails(
                userId, username, "masked", username + "@test.com",
                1, true, true, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                principal, null, principal.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Test
    @DisplayName("Strict Audit records authenticated actor, action, target, timestamp, correlationId, and masked snapshots")
    void logStrictAction_success_capturesAuthoritativeFields() {
        authenticateAdmin(101, "admin_root");

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("198.51.100.10");
        request.addHeader("User-Agent", "Mozilla/5.0 AdminWeb");
        request.addHeader("X-Request-Id", "req-audit-12345678");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));

        User beforeUser = User.builder().userId(202).username("u202").email("victim@example.com")
                .password("bcryptHash").role(Role.USER).status(UserStatus.ACTIVE).build();
        User afterUser = User.builder().userId(202).username("u202").email("victim@example.com")
                .password("bcryptHash").role(Role.USER).status(UserStatus.BANNED).build();

        AuditCommand command = AuditCommand.builder()
                .actionType(AuditActionType.USER_BAN)
                .targetType(AuditTargetType.USER)
                .targetId("202")
                .reason("Spam violation")
                .beforeSnapshot(UserAuditSnapshot.from(beforeUser))
                .afterSnapshot(UserAuditSnapshot.from(afterUser))
                .build();

        AuditLog saved = auditLogService.logStrictAction(command);

        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).saveAndFlush(captor.capture());

        AuditLog persisted = captor.getValue();
        assertEquals(101, persisted.getActorId());
        assertEquals("admin_root", persisted.getActorUsername());
        assertEquals(AuditActionType.USER_BAN, persisted.getActionType());
        assertEquals(AuditTargetType.USER, persisted.getTargetType());
        assertEquals("202", persisted.getTargetId());
        assertEquals("Spam violation", persisted.getReason());
        assertEquals(AuditResultStatus.SUCCESS, persisted.getResultStatus());
        assertEquals("198.51.100.10", persisted.getIpAddress());
        assertEquals("Mozilla/5.0 AdminWeb", persisted.getUserAgent());
        assertEquals("req-audit-12345678", persisted.getCorrelationId());
        assertNotNull(persisted.getCreatedAt());
        assertFalse(persisted.getBeforeDataJson().contains("bcryptHash"));
        assertTrue(persisted.getBeforeDataJson().contains("v***@example.com"));
        assertSame(persisted, saved);
    }

    @Test
    @DisplayName("Client cannot spoof actor via HTTP headers or mismatched expectedActorUsername")
    void logStrictAction_clientSpoofing_ignoredAndRejected() {
        authenticateAdmin(101, "real_admin");

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.55");
        // Untrusted client sends spoofed actor and proxy headers
        request.addHeader("X-Actor-Id", "9999");
        request.addHeader("X-Actor-Username", "super_fake_admin");
        request.addHeader("X-User-Id", "1");
        request.addHeader("X-Forwarded-For", "10.0.0.1");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));

        AuditCommand commandWithRealContext = AuditCommand.builder()
                .actionType(AuditActionType.SETTING_UPDATE)
                .targetType(AuditTargetType.SYSTEM_SETTING)
                .targetId("MAX_POST_LIMIT")
                .reason("Update setting")
                .build();

        AuditLog logged = auditLogService.logStrictAction(commandWithRealContext);
        assertEquals(101, logged.getActorId());
        assertEquals("real_admin", logged.getActorUsername());
        assertEquals("203.0.113.55", logged.getIpAddress());

        AuditCommand mismatchActorCmd = AuditCommand.builder()
                .actionType(AuditActionType.SETTING_UPDATE)
                .targetType(AuditTargetType.SYSTEM_SETTING)
                .targetId("MAX_POST_LIMIT")
                .expectedActorUsername("super_fake_admin")
                .build();

        assertThrows(ForbiddenException.class, () -> auditLogService.logStrictAction(mismatchActorCmd));
        verify(auditLogRepository, times(1)).saveAndFlush(any());
    }

    @Test
    @DisplayName("Unauthenticated or anonymous callers are rejected before audit persistence")
    void logStrictAction_unauthenticatedOrAnonymous_rejected() {
        SecurityContextHolder.clearContext();
        AuditCommand cmd = AuditCommand.builder()
                .actionType(AuditActionType.ITINERARY_MODERATE)
                .targetType(AuditTargetType.ITINERARY)
                .targetId("55")
                .build();

        assertThrows(UnauthorizedException.class, () -> auditLogService.logStrictAction(cmd));

        SecurityContextHolder.getContext().setAuthentication(
                new AnonymousAuthenticationToken("key", "anonymousUser",
                        List.of(new SimpleGrantedAuthority("ROLE_ANONYMOUS"))));
        assertThrows(UnauthorizedException.class, () -> auditLogService.logStrictAction(cmd));

        verify(auditLogRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("Strict Audit persistence failure throws AuditTrailPersistenceException without leaking secrets")
    void logStrictAction_dbFailure_throwsAuditTrailPersistenceExceptionSafely() {
        authenticateAdmin(101, "admin_root");
        when(auditLogRepository.saveAndFlush(any(AuditLog.class)))
                .thenThrow(new DataAccessResourceFailureException("Simulated DB down: secret_db_password_leak"));

        AuditCommand cmd = AuditCommand.builder()
                .actionType(AuditActionType.USER_ROLE_CHANGE)
                .targetType(AuditTargetType.USER)
                .targetId("300")
                .afterSnapshot(Map.of("role", "ADMIN", "password", "TopSecret123!"))
                .build();

        AuditTrailPersistenceException ex = assertThrows(
                AuditTrailPersistenceException.class,
                () -> auditLogService.logStrictAction(cmd));

        assertEquals(AuditTrailPersistenceException.DEFAULT_SAFE_MESSAGE, ex.getMessage());
        assertFalse(ex.getMessage().contains("TopSecret123!"));
        assertFalse(ex.getMessage().contains("secret_db_password_leak"));
    }

    @Test
    @DisplayName("Strict Audit executed inside a readOnly transaction is rejected immediately")
    void logStrictAction_readOnlyTransaction_rejected() {
        authenticateAdmin(101, "admin_root");
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setCurrentTransactionReadOnly(true);

        AuditCommand cmd = AuditCommand.builder()
                .actionType(AuditActionType.ITINERARY_PRIVATE_INSPECT)
                .targetType(AuditTargetType.ITINERARY)
                .targetId("88")
                .reason("Investigating report #99")
                .build();

        assertThrows(AuditTrailPersistenceException.class, () -> auditLogService.logStrictAction(cmd));
        verify(auditLogRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("Strict audit actions cannot be downgraded to best-effort telemetry")
    void recordBestEffortTelemetry_strictAction_rejected() {
        AuditCommand strictCmd = AuditCommand.builder()
                .actionType(AuditActionType.USER_BAN)
                .targetType(AuditTargetType.USER)
                .targetId("10")
                .build();

        assertThrows(IllegalArgumentException.class, () -> auditLogService.recordBestEffortTelemetry(strictCmd));
    }

    @Test
    @DisplayName("Best-effort telemetry catches sink errors cleanly without propagating or writing audit_logs")
    void recordBestEffortTelemetry_sinkFailure_swallowedSafely() {
        AtomicBoolean emitterInvoked = new AtomicBoolean(false);
        auditLogService.setTelemetryEmitter((actor, action, targetType, targetId, payload, corrId) -> {
            emitterInvoked.set(true);
            throw new RuntimeException("Telemetry collector offline");
        });

        AuditCommand telemetryCmd = AuditCommand.builder()
                .actionType(AuditActionType.TELEMETRY_OPERATIONAL)
                .targetType(AuditTargetType.SYSTEM)
                .targetId("health_probe")
                .afterSnapshot(Map.of("latencyMs", 42, "apiKey", "hidden_key"))
                .build();

        assertDoesNotThrow(() -> auditLogService.recordBestEffortTelemetry(telemetryCmd));
        assertTrue(emitterInvoked.get());
        verify(auditLogRepository, never()).saveAndFlush(any());
        verify(auditLogRepository, never()).save(any());
    }
}
