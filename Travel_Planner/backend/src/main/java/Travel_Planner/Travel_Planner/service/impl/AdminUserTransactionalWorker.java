package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.audit.UserAuditSnapshot;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserRoleRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.dto.response.UserAdminResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AdminRoleGuard;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.AdminRoleGuardRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.UserSessionService;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Isolated Spring Bean executing critical Admin User mutations inside a fresh
 * physical transaction ({@code REQUIRES_NEW}, {@code READ_COMMITTED}) protected by
 * {@code ADMIN_ROLE_MUTEX} pessimistic write lock.
 *
 * Separated from {@link AdminUserOrchestrationServiceImpl} to guarantee Spring AOP
 * proxy invocation on every {@code @Retryable} attempt without self-invocation bypass.
 */
@Component
public class AdminUserTransactionalWorker {

    private final AdminRoleGuardRepository adminRoleGuardRepository;
    private final UserRepository userRepository;
    private final UserSessionService userSessionService;
    private final AuditLogService auditLogService;

    public AdminUserTransactionalWorker(
            AdminRoleGuardRepository adminRoleGuardRepository,
            UserRepository userRepository,
            UserSessionService userSessionService,
            AuditLogService auditLogService) {
        this.adminRoleGuardRepository = adminRoleGuardRepository;
        this.userRepository = userRepository;
        this.userSessionService = userSessionService;
        this.auditLogService = auditLogService;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW, isolation = Isolation.READ_COMMITTED)
    public UserAdminResponse executeStatusUpdateInNewTransaction(
            Integer targetUserId,
            UpdateUserStatusRequest request,
            String actorUsername) {

        if (request.getStatus() != UserStatus.ACTIVE && request.getStatus() != UserStatus.BANNED) {
            throw new BadRequestException("Trạng thái hợp lệ chỉ có thể là ACTIVE hoặc BANNED.");
        }

        acquireAdminMutex(actorUsername);
        User actor = reloadAndVerifyActiveAdmin(actorUsername);
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));

        if (actor.getUserId().equals(target.getUserId())) {
            throw new BadRequestException("Không thể tự khóa hoặc tự thay đổi trạng thái tài khoản của chính mình.");
        }

        if (target.getStatus() == request.getStatus()) {
            throw new BadRequestException("Tài khoản hiện đã ở trạng thái " + request.getStatus().name() + ".");
        }

        if (request.getStatus() == UserStatus.BANNED
                && target.getRole() == Role.ADMIN
                && target.getStatus() == UserStatus.ACTIVE) {
            long activeAdminCount = userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE);
            if (activeAdminCount <= 1) {
                throw new BadRequestException("Không thể khóa quản trị viên hoạt động cuối cùng của hệ thống.");
            }
        }

        UserAuditSnapshot beforeSnapshot = UserAuditSnapshot.from(target);

        target.setStatus(request.getStatus());
        target = userRepository.saveAndFlush(target);

        if (request.getStatus() == UserStatus.BANNED) {
            userSessionService.revokeAllSessions(target.getUsername());
        }

        UserAuditSnapshot afterSnapshot = UserAuditSnapshot.from(target);
        AuditActionType actionType = request.getStatus() == UserStatus.BANNED
                ? AuditActionType.USER_BAN
                : AuditActionType.USER_UNBAN;

        auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(actionType)
                .targetType(AuditTargetType.USER)
                .targetId(String.valueOf(target.getUserId()))
                .reason(request.getReason().trim())
                .resultStatus(AuditResultStatus.SUCCESS)
                .beforeSnapshot(beforeSnapshot)
                .afterSnapshot(afterSnapshot)
                .expectedActorUsername(actor.getUsername())
                .build());

        return UserAdminResponse.from(target);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW, isolation = Isolation.READ_COMMITTED)
    public UserAdminResponse executeRoleUpdateInNewTransaction(
            Integer targetUserId,
            UpdateUserRoleRequest request,
            String actorUsername) {

        acquireAdminMutex(actorUsername);
        User actor = reloadAndVerifyActiveAdmin(actorUsername);
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));

        if (actor.getUserId().equals(target.getUserId())) {
            throw new BadRequestException("Không thể tự thay đổi vai trò của chính mình.");
        }

        if (target.getRole() == request.getRole()) {
            throw new BadRequestException("Tài khoản hiện đã mang vai trò " + request.getRole().name() + ".");
        }

        if (request.getRole() == Role.USER
                && target.getRole() == Role.ADMIN
                && target.getStatus() == UserStatus.ACTIVE) {
            long activeAdminCount = userRepository.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE);
            if (activeAdminCount <= 1) {
                throw new BadRequestException("Không thể hạ quyền quản trị viên hoạt động cuối cùng của hệ thống.");
            }
        }

        UserAuditSnapshot beforeSnapshot = UserAuditSnapshot.from(target);

        target.setRole(request.getRole());
        target = userRepository.saveAndFlush(target);

        // Revoke active sessions on privilege escalation or demotion to force clean JWT re-issuance
        userSessionService.revokeAllSessions(target.getUsername());

        UserAuditSnapshot afterSnapshot = UserAuditSnapshot.from(target);

        auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(AuditActionType.USER_ROLE_CHANGE)
                .targetType(AuditTargetType.USER)
                .targetId(String.valueOf(target.getUserId()))
                .reason(request.getReason().trim())
                .resultStatus(AuditResultStatus.SUCCESS)
                .beforeSnapshot(beforeSnapshot)
                .afterSnapshot(afterSnapshot)
                .expectedActorUsername(actor.getUsername())
                .build());

        return UserAdminResponse.from(target);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW, isolation = Isolation.READ_COMMITTED)
    public int executeRevokeSessionsInNewTransaction(
            Integer targetUserId,
            String reason,
            String actorUsername) {

        acquireAdminMutex(actorUsername);
        User actor = reloadAndVerifyActiveAdmin(actorUsername);
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));

        if (actor.getUserId().equals(target.getUserId())) {
            throw new BadRequestException("Không thể thu hồi toàn bộ phiên của chính mình từ màn hình Quản lý người dùng.");
        }

        UserAuditSnapshot beforeSnapshot = UserAuditSnapshot.from(target);
        int revokedCount = userSessionService.revokeAllSessions(target.getUsername());

        Map<String, Object> afterMetadata = new LinkedHashMap<>();
        afterMetadata.put("userId", target.getUserId());
        afterMetadata.put("username", target.getUsername());
        afterMetadata.put("revokedSessionCount", revokedCount);

        String effectiveReason = (reason != null && !reason.isBlank())
                ? reason.trim()
                : "Quản trị viên thu hồi toàn bộ phiên đăng nhập";

        auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(AuditActionType.USER_SESSIONS_REVOKE)
                .targetType(AuditTargetType.USER)
                .targetId(String.valueOf(target.getUserId()))
                .reason(effectiveReason)
                .resultStatus(AuditResultStatus.SUCCESS)
                .beforeSnapshot(beforeSnapshot)
                .afterSnapshot(afterMetadata)
                .expectedActorUsername(actor.getUsername())
                .build());

        return revokedCount;
    }

    private void acquireAdminMutex(String actorUsername) {
        AdminRoleGuard guard = adminRoleGuardRepository
                .findByGuardNameForUpdate(AdminRoleGuard.ADMIN_ROLE_MUTEX)
                .orElseThrow(() -> new IllegalStateException(
                        "Critical infrastructure error: ADMIN_ROLE_MUTEX row is missing from admin_role_guard."));
        guard.setLockedAt(LocalDateTime.now());
        guard.setLockedBy(actorUsername != null && actorUsername.length() > 50
                ? actorUsername.substring(0, 50)
                : actorUsername);
    }

    private User reloadAndVerifyActiveAdmin(String actorUsername) {
        if (actorUsername == null || actorUsername.isBlank()) {
            throw new AccessDeniedException("Không xác định được danh tính quản trị viên.");
        }
        User actor = userRepository.findByUsername(actorUsername)
                .orElseThrow(() -> new AccessDeniedException("Tài khoản quản trị viên không tồn tại."));
        if (actor.getStatus() != UserStatus.ACTIVE || actor.getRole() != Role.ADMIN) {
            throw new AccessDeniedException("Tài khoản của bạn đã bị khóa hoặc mất quyền quản trị.");
        }
        return actor;
    }
}
