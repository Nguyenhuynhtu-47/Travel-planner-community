package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.UpdateUserRoleRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.UserAdminDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.UserAdminResponse;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;

public interface AdminUserOrchestrationService {

    PageResponse<UserAdminResponse> getUsers(
            String keyword,
            Role role,
            UserStatus status,
            int page,
            int size,
            String sort);

    UserAdminDetailResponse getUserDetail(Integer targetUserId);

    UserAdminResponse updateUserStatusWithRetry(
            Integer targetUserId,
            UpdateUserStatusRequest request,
            String actorUsername);

    UserAdminResponse updateUserRoleWithRetry(
            Integer targetUserId,
            UpdateUserRoleRequest request,
            String actorUsername);

    int revokeUserSessionsWithRetry(
            Integer targetUserId,
            String reason,
            String actorUsername);
}
