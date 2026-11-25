package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.UpdateUserRoleRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateUserStatusRequest;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.UserAdminDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.UserAdminResponse;
import Travel_Planner.Travel_Planner.dto.response.UserSessionResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserSession;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.PostRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.UserSessionRepository;
import Travel_Planner.Travel_Planner.service.AdminUserOrchestrationService;
import jakarta.persistence.criteria.Predicate;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.resilience.annotation.Retryable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Orchestration & Retry Bean for Admin User Management.
 * Delegates mutating operations across Spring AOP proxy boundaries to
 * {@link AdminUserTransactionalWorker} so each retry attempt starts a fresh {@code REQUIRES_NEW} transaction.
 */
@Service
public class AdminUserOrchestrationServiceImpl implements AdminUserOrchestrationService {

    private final AdminUserTransactionalWorker worker;
    private final UserRepository userRepository;
    private final UserSessionRepository userSessionRepository;
    private final ItineraryRepository itineraryRepository;
    private final PostRepository postRepository;

    public AdminUserOrchestrationServiceImpl(
            AdminUserTransactionalWorker worker,
            UserRepository userRepository,
            UserSessionRepository userSessionRepository,
            ItineraryRepository itineraryRepository,
            PostRepository postRepository) {
        this.worker = worker;
        this.userRepository = userRepository;
        this.userSessionRepository = userSessionRepository;
        this.itineraryRepository = itineraryRepository;
        this.postRepository = postRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<UserAdminResponse> getUsers(
            String keyword,
            Role role,
            UserStatus status,
            int page,
            int size,
            String sort) {
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ.");
        }

        int cappedSize = Math.min(size, 50);
        Pageable pageable = PageRequest.of(page, cappedSize, resolveSort(sort));

        Specification<User> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (role != null) {
                predicates.add(cb.equal(root.get("role"), role));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (keyword != null && !keyword.trim().isEmpty()) {
                String escaped = escapeLike(keyword.trim().toLowerCase(Locale.ROOT));
                String pattern = "%" + escaped + "%";
                Predicate byUsername = cb.like(cb.lower(root.get("username")), pattern, '!');
                Predicate byHandle = cb.like(cb.lower(root.get("handle")), pattern, '!');
                Predicate byEmail = cb.like(cb.lower(root.get("email")), pattern, '!');
                Predicate byFullName = cb.like(cb.lower(cb.coalesce(root.get("fullName"), "")), pattern, '!');
                predicates.add(cb.or(byUsername, byHandle, byEmail, byFullName));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        Page<UserAdminResponse> mapped = userRepository.findAll(spec, pageable).map(UserAdminResponse::from);
        return PageResponse.from(mapped);
    }

    @Override
    @Transactional(readOnly = true)
    public UserAdminDetailResponse getUserDetail(Integer targetUserId) {
        User user = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));

        long itineraryCount = itineraryRepository.countByUser_UserId(targetUserId);
        long postCount = postRepository.countByAuthor_UserId(targetUserId);
        List<UserSession> rawSessions = userSessionRepository.findByUser_UserIdOrderByCreatedAtDesc(targetUserId);

        long activeSessionCount = rawSessions.stream()
                .filter(UserSession::isActive)
                .count();

        List<UserSessionResponse> sessionResponses = rawSessions.stream()
                .map(s -> UserSessionResponse.builder()
                        .sessionId(s.getSessionId())
                        .deviceInfo(s.getDeviceInfo())
                        .ipAddress(s.getIpAddress())
                        .status(s.getStatus())
                        .createdAt(s.getCreatedAt())
                        .lastActiveAt(s.getLastActiveAt())
                        .expiresAt(s.getExpiresAt())
                        .isCurrentSession(false)
                        .build())
                .toList();

        return UserAdminDetailResponse.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .handle(user.getHandle())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .avatar(user.getAvatar())
                .phone(user.getPhone())
                .address(user.getAddress())
                .bio(user.getBio())
                .role(user.getRole())
                .status(user.getStatus())
                .emailVerified(user.getEmailVerified())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .itineraryCount(itineraryCount)
                .postCount(postCount)
                .activeSessionCount(activeSessionCount)
                .sessions(sessionResponses)
                .build();
    }

    @Override
    @Retryable(
            includes = {CannotAcquireLockException.class, PessimisticLockingFailureException.class},
            maxRetries = 2,
            delay = 100,
            multiplier = 2.0
    )
    public UserAdminResponse updateUserStatusWithRetry(
            Integer targetUserId,
            UpdateUserStatusRequest request,
            String actorUsername) {
        return worker.executeStatusUpdateInNewTransaction(targetUserId, request, actorUsername);
    }

    @Override
    @Retryable(
            includes = {CannotAcquireLockException.class, PessimisticLockingFailureException.class},
            maxRetries = 2,
            delay = 100,
            multiplier = 2.0
    )
    public UserAdminResponse updateUserRoleWithRetry(
            Integer targetUserId,
            UpdateUserRoleRequest request,
            String actorUsername) {
        return worker.executeRoleUpdateInNewTransaction(targetUserId, request, actorUsername);
    }

    @Override
    @Retryable(
            includes = {CannotAcquireLockException.class, PessimisticLockingFailureException.class},
            maxRetries = 2,
            delay = 100,
            multiplier = 2.0
    )
    public int revokeUserSessionsWithRetry(
            Integer targetUserId,
            String reason,
            String actorUsername) {
        return worker.executeRevokeSessionsInNewTransaction(targetUserId, reason, actorUsername);
    }

    private Sort resolveSort(String sortParam) {
        if (sortParam == null || sortParam.isBlank()) {
            return Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("userId"));
        }
        String[] parts = sortParam.split(",");
        String field = parts[0].trim();
        Sort.Direction direction = (parts.length > 1 && "asc".equalsIgnoreCase(parts[1].trim()))
                ? Sort.Direction.ASC
                : Sort.Direction.DESC;

        String allowedField = switch (field) {
            case "username", "handle", "email", "role", "status", "createdAt", "updatedAt", "userId" -> field;
            default -> "createdAt";
        };
        return Sort.by(new Sort.Order(direction, allowedField), Sort.Order.desc("userId"));
    }

    private String escapeLike(String value) {
        return value
                .replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
    }
}
