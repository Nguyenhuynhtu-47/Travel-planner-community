package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.UpdateUserRoleRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.RevokeSessionResponse;
import Travel_Planner.Travel_Planner.dto.response.UserAdminDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.UserAdminResponse;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.service.AdminUserOrchestrationService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@Validated
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/admin/users")
public class AdminUserController {

    private final AdminUserOrchestrationService adminUserOrchestrationService;

    public AdminUserController(AdminUserOrchestrationService adminUserOrchestrationService) {
        this.adminUserOrchestrationService = adminUserOrchestrationService;
    }

    @GetMapping
    public ResponseEntity<PageResponse<UserAdminResponse>> getUsers(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Role role,
            @RequestParam(required = false) UserStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ResponseEntity.ok(adminUserOrchestrationService.getUsers(keyword, role, status, page, size, sort));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserAdminDetailResponse> getUserDetail(@PathVariable("id") Integer id) {
        return ResponseEntity.ok(adminUserOrchestrationService.getUserDetail(id));
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<UserAdminResponse> updateUserStatus(
            @PathVariable("id") Integer id,
            @Valid @RequestBody UpdateUserStatusRequest request,
            @AuthenticationPrincipal UserDetails admin) {
        String actorUsername = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(adminUserOrchestrationService.updateUserStatusWithRetry(id, request, actorUsername));
    }

    @PatchMapping("/{id}/role")
    public ResponseEntity<UserAdminResponse> updateUserRole(
            @PathVariable("id") Integer id,
            @Valid @RequestBody UpdateUserRoleRequest request,
            @AuthenticationPrincipal UserDetails admin) {
        String actorUsername = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(adminUserOrchestrationService.updateUserRoleWithRetry(id, request, actorUsername));
    }

    @PostMapping("/{id}/sessions/revoke-all")
    public ResponseEntity<RevokeSessionResponse> revokeAllUserSessions(
            @PathVariable("id") Integer id,
            @RequestParam(required = false) String reason,
            @AuthenticationPrincipal UserDetails admin) {
        String actorUsername = admin != null ? admin.getUsername() : null;
        int revokedCount = adminUserOrchestrationService.revokeUserSessionsWithRetry(id, reason, actorUsername);
        return ResponseEntity.ok(RevokeSessionResponse.builder()
                .message("Đã thu hồi toàn bộ phiên đăng nhập của người dùng")
                .revokedCount(revokedCount)
                .build());
    }
}
