package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.model.AdminRoleGuard;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.AdminRoleGuardRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.SocialNotificationService;
import Travel_Planner.Travel_Planner.service.UserSessionService;
import Travel_Planner.Travel_Planner.service.impl.AdminUserTransactionalWorker;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AdminUserModerationNotificationTest {
    @Mock private AdminRoleGuardRepository guards;
    @Mock private UserRepository users;
    @Mock private UserSessionService sessions;
    @Mock private AuditLogService audit;
    @Mock private SocialNotificationService notifications;

    @Test
    void banCreatesUserFacingNoticeInsideSuccessfulStatusTransaction() {
        User admin = user(1, "admin", Role.ADMIN, UserStatus.ACTIVE);
        User target = user(2, "traveler", Role.USER, UserStatus.ACTIVE);
        when(guards.findByGuardNameForUpdate(AdminRoleGuard.ADMIN_ROLE_MUTEX))
                .thenReturn(Optional.of(new AdminRoleGuard()));
        when(users.findByUsername("admin")).thenReturn(Optional.of(admin));
        when(users.findById(2)).thenReturn(Optional.of(target));
        when(users.saveAndFlush(target)).thenReturn(target);
        when(sessions.revokeAllSessions("traveler")).thenReturn(1);

        AdminUserTransactionalWorker worker = new AdminUserTransactionalWorker(
                guards, users, sessions, audit, notifications);
        worker.executeStatusUpdateInNewTransaction(2,
                new UpdateUserStatusRequest(UserStatus.BANNED, "policy violation"), "admin");

        verify(audit).logStrictAction(any());
        verify(notifications).accountModerationTransition(eq(target), any(User.class),
                eq(UserStatus.ACTIVE), eq(UserStatus.BANNED), anyString());
        assertEquals(UserStatus.BANNED, target.getStatus());
    }

    private static User user(Integer id, String username, Role role, UserStatus status) {
        return User.builder().userId(id).username(username).handle(username).fullName(username)
                .role(role).status(status).build();
    }
}
