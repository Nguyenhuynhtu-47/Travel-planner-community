package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.UserSessionResponse;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserSession;
import Travel_Planner.Travel_Planner.model.enums.UserSessionStatus;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.UserSessionRepository;
import Travel_Planner.Travel_Planner.service.UserSessionService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class UserSessionServiceImpl implements UserSessionService {

    private final UserSessionRepository userSessionRepository;
    private final UserRepository userRepository;

    public UserSessionServiceImpl(UserSessionRepository userSessionRepository, UserRepository userRepository) {
        this.userSessionRepository = userSessionRepository;
        this.userRepository = userRepository;
    }

    @Override
    @Transactional
    public UserSession createSession(User user, String deviceInfo, String ipAddress, long expirationMs) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expiresAt = now.plusNanos(expirationMs * 1_000_000L);

        UserSession session = UserSession.builder()
                .sessionId(UUID.randomUUID().toString())
                .user(user)
                .deviceInfo(deviceInfo != null && !deviceInfo.isBlank() ? deviceInfo : "Thiết bị không xác định")
                .ipAddress(ipAddress != null && !ipAddress.isBlank() ? ipAddress : "0.0.0.0")
                .status(UserSessionStatus.ACTIVE)
                .createdAt(now)
                .lastActiveAt(now)
                .expiresAt(expiresAt)
                .build();

        return userSessionRepository.save(session);
    }

    @Override
    @Transactional(readOnly = true)
    public boolean isSessionActive(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return false;
        }

        return userSessionRepository.findBySessionId(sessionId)
                .map(session -> session.getStatus() == UserSessionStatus.ACTIVE && !session.isExpired())
                .orElse(false);
    }

    @Override
    @Transactional
    public void touchSession(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return;
        }

        userSessionRepository.findBySessionId(sessionId).ifPresent(session -> {
            if (session.getStatus() == UserSessionStatus.ACTIVE) {
                // Throttle touch updates: only update if lastActiveAt was more than 2 minutes ago
                LocalDateTime now = LocalDateTime.now();
                if (session.getLastActiveAt() == null || session.getLastActiveAt().isBefore(now.minusMinutes(2))) {
                    userSessionRepository.updateLastActiveAt(sessionId, now);
                }
            }
        });
    }

    @Override
    @Transactional
    public void revokeSession(String sessionId, String currentUsername) {
        UserSession session = userSessionRepository.findBySessionId(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiên đăng nhập"));

        User sessionUser = session.getUser();
        if (sessionUser == null || !sessionUser.getUsername().equalsIgnoreCase(currentUsername)) {
            throw new ForbiddenException("Bạn không có quyền thao tác trên phiên đăng nhập của tài khoản khác");
        }

        session.setStatus(UserSessionStatus.REVOKED);
        userSessionRepository.save(session);
    }

    @Override
    @Transactional
    public int revokeOtherSessions(String currentUsername, String currentSessionId) {
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        return userSessionRepository.revokeOtherSessionsForUser(
                user.getUserId(),
                currentSessionId,
                UserSessionStatus.ACTIVE,
                UserSessionStatus.REVOKED
        );
    }

    @Override
    @Transactional
    public int revokeAllSessions(String currentUsername) {
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        // Bump token version as well for defense in depth
        user.setTokenVersion((user.getTokenVersion() != null ? user.getTokenVersion() : 1) + 1);
        userRepository.save(user);

        return userSessionRepository.revokeAllSessionsForUser(
                user.getUserId(),
                UserSessionStatus.ACTIVE,
                UserSessionStatus.REVOKED
        );
    }

    @Override
    @Transactional(readOnly = true)
    public List<UserSessionResponse> getUserSessions(String currentUsername, String currentSessionId) {
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        List<UserSession> sessions = userSessionRepository.findByUser_UserIdOrderByCreatedAtDesc(user.getUserId());

        return sessions.stream()
                .map(s -> UserSessionResponse.builder()
                        .sessionId(s.getSessionId())
                        .deviceInfo(s.getDeviceInfo())
                        .ipAddress(s.getIpAddress())
                        .status(s.isExpired() && s.getStatus() == UserSessionStatus.ACTIVE ? UserSessionStatus.EXPIRED : s.getStatus())
                        .createdAt(s.getCreatedAt())
                        .lastActiveAt(s.getLastActiveAt())
                        .expiresAt(s.getExpiresAt())
                        .isCurrentSession(currentSessionId != null && currentSessionId.equals(s.getSessionId()))
                        .build())
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public void revokeCurrentSession(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return;
        }

        userSessionRepository.findBySessionId(sessionId).ifPresent(session -> {
            session.setStatus(UserSessionStatus.REVOKED);
            userSessionRepository.save(session);
        });
    }
}
