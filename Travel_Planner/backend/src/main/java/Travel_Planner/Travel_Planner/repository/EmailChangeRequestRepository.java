package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.EmailChangeRequest;
import Travel_Planner.Travel_Planner.model.enums.EmailChangeStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface EmailChangeRequestRepository extends JpaRepository<EmailChangeRequest, Long> {

    Optional<EmailChangeRequest> findTopByUser_UserIdAndStatusOrderByCreatedAtDesc(
            Integer userId,
            EmailChangeStatus status);

    Optional<EmailChangeRequest> findTopByUser_UserIdAndNewEmailAndStatusOrderByCreatedAtDesc(
            Integer userId,
            String newEmail,
            EmailChangeStatus status);

    @Modifying
    @Query("UPDATE EmailChangeRequest r SET r.status = :newStatus WHERE r.user.userId = :userId AND r.status = :currentStatus")
    int cancelAllPendingRequestsForUser(
            @Param("userId") Integer userId,
            @Param("currentStatus") EmailChangeStatus currentStatus,
            @Param("newStatus") EmailChangeStatus newStatus);

    @Modifying
    @Query("UPDATE EmailChangeRequest r SET r.status = :newStatus WHERE r.status = :pendingStatus AND r.expiresAt < :now")
    int markExpiredRequests(
            @Param("pendingStatus") EmailChangeStatus pendingStatus,
            @Param("newStatus") EmailChangeStatus newStatus,
            @Param("now") LocalDateTime now);
}
