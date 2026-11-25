package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.UpdateUserRoleRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.dto.response.UserAdminResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.model.AdminRoleGuard;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.AdminRoleGuardRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.CustomUserDetails;
import Travel_Planner.Travel_Planner.service.AdminUserOrchestrationService;
import Travel_Planner.Travel_Planner.service.impl.AdminUserTransactionalWorker;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.reset;

@SpringBootTest
class AdminUserConcurrencyIntegrationTest {

    @Autowired
    private AdminUserOrchestrationService orchestrationService;

    @MockitoSpyBean
    private AdminUserTransactionalWorker workerSpy;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AdminRoleGuardRepository adminRoleGuardRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private final List<Integer> createdUserIds = new CopyOnWriteArrayList<>();

    @BeforeEach
    void setUp() {
        reset(workerSpy);
        jdbcTemplate.execute("DELETE FROM audit_logs");
    }

    @AfterEach
    void tearDown() {
        reset(workerSpy);
        SecurityContextHolder.clearContext();
        jdbcTemplate.execute("DELETE FROM audit_logs");
        for (Integer uid : createdUserIds) {
            try {
                jdbcTemplate.update("DELETE FROM user_sessions WHERE user_id = ?", uid);
                userRepository.deleteById(uid);
            } catch (Exception ignored) {}
        }
        createdUserIds.clear();
    }

    private User createUser(String prefix, Role role, UserStatus status) {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        User user = userRepository.saveAndFlush(User.builder()
                .username(prefix + "_" + suffix)
                .handle((prefix + "_" + suffix).toLowerCase())
                .password("TestPwd#123")
                .email(prefix + "_" + suffix + "@example.com")
                .fullName(prefix + " Full")
                .role(role)
                .status(status)
                .emailVerified(true)
                .tokenVersion(1)
                .build());
        createdUserIds.add(user.getUserId());
        return user;
    }

    private void setSecurityContext(User actor) {
        CustomUserDetails principal = new CustomUserDetails(
                actor.getUserId(), actor.getUsername(), actor.getPassword(),
                actor.getEmail(), actor.getTokenVersion(), true, true,
                List.of(new SimpleGrantedAuthority("ROLE_" + actor.getRole().name())));
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
    }

    private long countActiveAdminsInScopedUsers() {
        return userRepository.findAllById(createdUserIds).stream()
                .filter(u -> u.getRole() == Role.ADMIN && u.getStatus() == UserStatus.ACTIVE)
                .count();
    }

    @Test
    @DisplayName("Test 1: Anti Self-Demotion rejects Admin demoting self")
    void antiSelfDemotion_rejected() {
        User admin1 = createUser("self_dem", Role.ADMIN, UserStatus.ACTIVE);
        User admin2 = createUser("other_adm", Role.ADMIN, UserStatus.ACTIVE);
        setSecurityContext(admin1);

        assertThrows(BadRequestException.class, () ->
                orchestrationService.updateUserRoleWithRetry(
                        admin1.getUserId(),
                        new UpdateUserRoleRequest(Role.USER, "Self demotion attempt"),
                        admin1.getUsername()));

        assertEquals(Role.ADMIN, userRepository.findById(admin1.getUserId()).orElseThrow().getRole());
        assertEquals(Role.ADMIN, userRepository.findById(admin2.getUserId()).orElseThrow().getRole());
    }

    @Test
    @DisplayName("Test 2: Anti Self-Ban rejects Admin banning self")
    void antiSelfBan_rejected() {
        User admin1 = createUser("self_ban", Role.ADMIN, UserStatus.ACTIVE);
        User admin2 = createUser("other_adm2", Role.ADMIN, UserStatus.ACTIVE);
        setSecurityContext(admin1);

        assertThrows(BadRequestException.class, () ->
                orchestrationService.updateUserStatusWithRetry(
                        admin1.getUserId(),
                        new UpdateUserStatusRequest(UserStatus.BANNED, "Self ban attempt"),
                        admin1.getUsername()));

        assertEquals(UserStatus.ACTIVE, userRepository.findById(admin1.getUserId()).orElseThrow().getStatus());
        assertEquals(UserStatus.ACTIVE, userRepository.findById(admin2.getUserId()).orElseThrow().getStatus());
    }

    @Test
    @DisplayName("Test 3: Last-Admin Demotion rejected when only 1 ACTIVE ADMIN exists in DB")
    void lastAdminDemotion_rejected() {
        // Ensure clean baseline of active admins in test DB
        long preExistingActiveAdmins = userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE);
        assertEquals(0L, preExistingActiveAdmins, "Test DB should have 0 pre-existing active admins");

        User onlyAdmin = createUser("only_adm", Role.ADMIN, UserStatus.ACTIVE);
        User adminA = createUser("adm_a", Role.ADMIN, UserStatus.ACTIVE);

        setSecurityContext(adminA);
        orchestrationService.updateUserRoleWithRetry(
                onlyAdmin.getUserId(),
                new UpdateUserRoleRequest(Role.USER, "Demote first of two"),
                adminA.getUsername());
        assertEquals(1L, userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE));

        // Now only adminA is ACTIVE ADMIN; self-demote also blocked, and even an inactive/external guard check enforces count <= 1
        assertThrows(BadRequestException.class, () ->
                orchestrationService.updateUserRoleWithRetry(
                        adminA.getUserId(),
                        new UpdateUserRoleRequest(Role.USER, "Cannot demote last admin"),
                        adminA.getUsername()));
        assertEquals(1L, userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE));
    }

    @Test
    @DisplayName("Test 4: Last-Admin Ban rejected so system never drops to 0 ACTIVE ADMIN")
    void lastAdminBan_rejected() {
        long preExistingActiveAdmins = userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE);
        assertEquals(0L, preExistingActiveAdmins);

        User adminA = createUser("last_ban_a", Role.ADMIN, UserStatus.ACTIVE);
        User adminB = createUser("last_ban_b", Role.ADMIN, UserStatus.ACTIVE);

        setSecurityContext(adminA);
        orchestrationService.updateUserStatusWithRetry(
                adminB.getUserId(),
                new UpdateUserStatusRequest(UserStatus.BANNED, "Ban second admin"),
                adminA.getUsername());

        assertEquals(1L, userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE));

        // Now adminA is sole ACTIVE ADMIN; cannot be banned
        assertThrows(BadRequestException.class, () ->
                orchestrationService.updateUserStatusWithRetry(
                        adminA.getUserId(),
                        new UpdateUserStatusRequest(UserStatus.BANNED, "Attempt ban last admin"),
                        adminA.getUsername()));
        assertEquals(1L, userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE));
    }

    @Test
    @DisplayName("Test 5: Two active admins concurrently demote each other -> one succeeds, second fails actor re-validation, 1 active admin remains")
    void concurrentDemotion_actorPrivilegeMaintained_invariantMaintained() throws Exception {
        User adminA = createUser("conc_a", Role.ADMIN, UserStatus.ACTIVE);
        User adminB = createUser("conc_b", Role.ADMIN, UserStatus.ACTIVE);

        CountDownLatch startGate = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);

        Callable<Throwable> task1 = () -> {
            startGate.await();
            setSecurityContext(adminA);
            try {
                orchestrationService.updateUserRoleWithRetry(
                        adminB.getUserId(),
                        new UpdateUserRoleRequest(Role.USER, "A demotes B"),
                        adminA.getUsername());
                return null;
            } catch (Throwable t) {
                return t;
            } finally {
                SecurityContextHolder.clearContext();
            }
        };

        Callable<Throwable> task2 = () -> {
            startGate.await();
            setSecurityContext(adminB);
            try {
                orchestrationService.updateUserRoleWithRetry(
                        adminA.getUserId(),
                        new UpdateUserRoleRequest(Role.USER, "B demotes A"),
                        adminB.getUsername());
                return null;
            } catch (Throwable t) {
                return t;
            } finally {
                SecurityContextHolder.clearContext();
            }
        };

        Future<Throwable> f1 = pool.submit(task1);
        Future<Throwable> f2 = pool.submit(task2);
        startGate.countDown();

        Throwable r1 = f1.get(15, TimeUnit.SECONDS);
        Throwable r2 = f2.get(15, TimeUnit.SECONDS);
        pool.shutdownNow();

        // Exactly ONE succeeded (null) and ONE was rejected with AccessDeniedException or BadRequestException
        boolean oneSucceededOneRejected = (r1 == null && r2 != null) || (r1 != null && r2 == null);
        assertTrue(oneSucceededOneRejected,
                "Expected exactly 1 success and 1 rejection, got r1=" + r1 + ", r2=" + r2);
        Throwable rejection = r1 != null ? r1 : r2;
        assertInstanceOf(AccessDeniedException.class, rejection,
                "Second thread must fail actor privilege re-validation with AccessDeniedException");

        assertEquals(1L, countActiveAdminsInScopedUsers(),
                "Database MUST retain exactly 1 ACTIVE ADMIN after concurrent mutual demotion");
    }

    @Test
    @DisplayName("Test 6: Concurrent Promote USER and Demote other ADMIN execute cleanly under mutex leaving 2 ACTIVE ADMIN")
    void concurrentPromoteAndDemote_success() throws Exception {
        User adminA = createUser("prom_a", Role.ADMIN, UserStatus.ACTIVE);
        User adminB = createUser("prom_b", Role.ADMIN, UserStatus.ACTIVE);
        User userC = createUser("prom_c", Role.USER, UserStatus.ACTIVE);

        CountDownLatch startGate = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);

        Future<UserAdminResponse> promoteFuture = pool.submit(() -> {
            startGate.await();
            setSecurityContext(adminA);
            try {
                return orchestrationService.updateUserRoleWithRetry(
                        userC.getUserId(),
                        new UpdateUserRoleRequest(Role.ADMIN, "Promote user C"),
                        adminA.getUsername());
            } finally {
                SecurityContextHolder.clearContext();
            }
        });

        Future<UserAdminResponse> demoteFuture = pool.submit(() -> {
            startGate.await();
            setSecurityContext(adminA);
            try {
                return orchestrationService.updateUserRoleWithRetry(
                        adminB.getUserId(),
                        new UpdateUserRoleRequest(Role.USER, "Demote admin B"),
                        adminA.getUsername());
            } finally {
                SecurityContextHolder.clearContext();
            }
        });

        startGate.countDown();
        assertEquals(Role.ADMIN, promoteFuture.get(15, TimeUnit.SECONDS).getRole());
        assertEquals(Role.USER, demoteFuture.get(15, TimeUnit.SECONDS).getRole());
        pool.shutdownNow();

        assertEquals(2L, countActiveAdminsInScopedUsers(), "admin_A and user_C must both be ACTIVE ADMIN");
        assertEquals(Role.ADMIN, userRepository.findById(adminA.getUserId()).orElseThrow().getRole());
        assertEquals(Role.USER, userRepository.findById(adminB.getUserId()).orElseThrow().getRole());
        assertEquals(Role.ADMIN, userRepository.findById(userC.getUserId()).orElseThrow().getRole());
    }

    @Test
    @DisplayName("Test 7: Concurrent Ban and Demote with 3 ACTIVE ADMINs (distinct actors admin_A & admin_B targeting admin_C) leaves 2 ACTIVE ADMINs")
    void concurrentBanAndDemote_lastAdminProtected() throws Exception {
        // Explicit 3 ACTIVE ADMIN setup per approved roadmap specification
        User adminA = createUser("bd_a", Role.ADMIN, UserStatus.ACTIVE);
        User adminB = createUser("bd_b", Role.ADMIN, UserStatus.ACTIVE);
        User adminC = createUser("bd_c", Role.ADMIN, UserStatus.ACTIVE);

        CountDownLatch startGate = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);

        // Thread 1: actor = adminA, target = adminC, action = DEMOTE
        Future<UserAdminResponse> demoteFuture = pool.submit(() -> {
            startGate.await();
            setSecurityContext(adminA);
            try {
                return orchestrationService.updateUserRoleWithRetry(
                        adminC.getUserId(),
                        new UpdateUserRoleRequest(Role.USER, "Demote admin C"),
                        adminA.getUsername());
            } finally {
                SecurityContextHolder.clearContext();
            }
        });

        // Thread 2: actor = adminB, target = adminC, action = BAN
        Future<UserAdminResponse> banFuture = pool.submit(() -> {
            startGate.await();
            setSecurityContext(adminB);
            try {
                return orchestrationService.updateUserStatusWithRetry(
                        adminC.getUserId(),
                        new UpdateUserStatusRequest(UserStatus.BANNED, "Ban admin C"),
                        adminB.getUsername());
            } finally {
                SecurityContextHolder.clearContext();
            }
        });

        startGate.countDown();
        assertNotNull(demoteFuture.get(15, TimeUnit.SECONDS));
        assertNotNull(banFuture.get(15, TimeUnit.SECONDS));
        pool.shutdownNow();

        User reloadedC = userRepository.findById(adminC.getUserId()).orElseThrow();
        assertEquals(Role.USER, reloadedC.getRole());
        assertEquals(UserStatus.BANNED, reloadedC.getStatus());
        assertEquals(2L, countActiveAdminsInScopedUsers(),
                "Exactly 2 ACTIVE ADMINs (admin_A and admin_B) must remain; invariant never drops below 1");
    }

    @Test
    @DisplayName("Test 8: Actor demoted while waiting on InnoDB ADMIN_ROLE_MUTEX is rejected immediately with AccessDeniedException")
    void actorLosesPrivilegeWhileWaitingForMutex_rejected() throws Exception {
        User adminA = createUser("wait_a", Role.ADMIN, UserStatus.ACTIVE);
        User adminB = createUser("wait_b", Role.ADMIN, UserStatus.ACTIVE);
        User adminC = createUser("wait_c", Role.ADMIN, UserStatus.ACTIVE);

        TransactionTemplate txTemplate = new TransactionTemplate(transactionManager);
        CountDownLatch mutexHeldLatch = new CountDownLatch(1);
        CountDownLatch thread2AboutToBlockLatch = new CountDownLatch(1);

        ExecutorService pool = Executors.newFixedThreadPool(2);

        // Thread 1 holds ADMIN_ROLE_MUTEX, waits until Thread 2 enters lock queue, demotes adminB, then commits
        Future<Void> holderFuture = pool.submit(() -> {
            txTemplate.executeWithoutResult(status -> {
                adminRoleGuardRepository.findByGuardNameForUpdate(AdminRoleGuard.ADMIN_ROLE_MUTEX).orElseThrow();
                mutexHeldLatch.countDown();
                try {
                    assertTrue(thread2AboutToBlockLatch.await(5, TimeUnit.SECONDS));
                    Thread.sleep(200); // Ensure Thread 2 is waiting on InnoDB row lock
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
                User targetB = userRepository.findById(adminB.getUserId()).orElseThrow();
                targetB.setRole(Role.USER);
                userRepository.saveAndFlush(targetB);
            });
            return null;
        });

        // Thread 2 acts as adminB attempting to BAN adminC while waiting for ADMIN_ROLE_MUTEX
        Future<Throwable> blockedActorFuture = pool.submit(() -> {
            assertTrue(mutexHeldLatch.await(5, TimeUnit.SECONDS));
            setSecurityContext(adminB);
            thread2AboutToBlockLatch.countDown();
            try {
                orchestrationService.updateUserStatusWithRetry(
                        adminC.getUserId(),
                        new UpdateUserStatusRequest(UserStatus.BANNED, "Delayed stale admin action"),
                        adminB.getUsername());
                return null;
            } catch (Throwable t) {
                return t;
            } finally {
                SecurityContextHolder.clearContext();
            }
        });

        holderFuture.get(15, TimeUnit.SECONDS);
        Throwable blockedResult = blockedActorFuture.get(15, TimeUnit.SECONDS);
        pool.shutdownNow();

        assertNotNull(blockedResult, "Thread 2 must be rejected once it acquires lock and reloads demoted actor");
        assertInstanceOf(AccessDeniedException.class, blockedResult);
        assertEquals(UserStatus.ACTIVE, userRepository.findById(adminC.getUserId()).orElseThrow().getStatus(),
                "adminC MUST remain ACTIVE because adminB lost ADMIN privilege before executing");
    }

    @Test
    @DisplayName("Spring @Retryable retries CannotAcquireLockException across bean boundary into a clean REQUIRES_NEW transaction")
    void retryableOrchestration_retriesLockContentionAcrossAopProxy() {
        User adminA = createUser("rty_a", Role.ADMIN, UserStatus.ACTIVE);
        User userTarget = createUser("rty_u", Role.USER, UserStatus.ACTIVE);
        setSecurityContext(adminA);

        AtomicInteger attempts = new AtomicInteger(0);
        doAnswer(invocation -> {
            if (attempts.incrementAndGet() == 1) {
                throw new CannotAcquireLockException("Simulated transient InnoDB lock wait timeout");
            }
            return invocation.callRealMethod();
        }).when(workerSpy).executeStatusUpdateInNewTransaction(
                eq(userTarget.getUserId()), any(UpdateUserStatusRequest.class), eq(adminA.getUsername()));

        UserAdminResponse response = orchestrationService.updateUserStatusWithRetry(
                userTarget.getUserId(),
                new UpdateUserStatusRequest(UserStatus.BANNED, "Retry test"),
                adminA.getUsername());

        assertEquals(2, attempts.get(), "Must have retried once after CannotAcquireLockException");
        assertEquals(UserStatus.BANNED, response.getStatus());
        assertEquals(UserStatus.BANNED, userRepository.findById(userTarget.getUserId()).orElseThrow().getStatus());
    }
}
