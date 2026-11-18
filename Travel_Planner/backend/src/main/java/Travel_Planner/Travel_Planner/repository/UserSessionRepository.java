package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.UserSession;
import Travel_Planner.Travel_Planner.model.enums.UserSessionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface UserSessionRepository extends JpaRepository<UserSession, String> {

    Optional<UserSession> findBySessionId(String sessionId);

    List<UserSession> findByUser_UserIdOrderByCreatedAtDesc(Integer userId);

    List<UserSession> findByUser_UsernameOrderByCreatedAtDesc(String username);

    List<UserSession> findByUser_UserIdAndStatusOrderByCreatedAtDesc(Integer userId, UserSessionStatus status);

    @Modifying
    @Query("UPDATE UserSession s SET s.status = :newStatus WHERE s.user.userId = :userId AND s.status = :currentStatus")
    int revokeAllSessionsForUser(
            @Param("userId") Integer userId,
            @Param("currentStatus") UserSessionStatus currentStatus,
            @Param("newStatus") UserSessionStatus newStatus);

    @Modifying
    @Query("UPDATE UserSession s SET s.status = :newStatus WHERE s.user.userId = :userId AND s.sessionId <> :excludedSessionId AND s.status = :currentStatus")
    int revokeOtherSessionsForUser(
            @Param("userId") Integer userId,
            @Param("excludedSessionId") String excludedSessionId,
            @Param("currentStatus") UserSessionStatus currentStatus,
            @Param("newStatus") UserSessionStatus newStatus);

    @Modifying
    @Query("UPDATE UserSession s SET s.lastActiveAt = :lastActiveAt WHERE s.sessionId = :sessionId")
    int updateLastActiveAt(
            @Param("sessionId") String sessionId,
            @Param("lastActiveAt") LocalDateTime lastActiveAt);

    @Modifying
    @Query("UPDATE UserSession s SET s.status = :newStatus WHERE s.status = :activeStatus AND s.expiresAt < :now")
    int markExpiredSessions(
            @Param("activeStatus") UserSessionStatus activeStatus,
            @Param("newStatus") UserSessionStatus newStatus,
            @Param("now") LocalDateTime now);
}
