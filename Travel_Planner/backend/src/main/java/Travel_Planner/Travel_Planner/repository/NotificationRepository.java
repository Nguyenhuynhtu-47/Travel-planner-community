package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Notification;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Page;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @Query(value = "select n from Notification n left join fetch n.actor "
            + "where n.actionType is not null "
            + "and (:targetType is null or n.targetType = :targetType) "
            + "and (:targetId is null or n.targetId = :targetId) "
            + "order by n.createdAt desc, n.notificationId desc",
            countQuery = "select count(n) from Notification n where n.actionType is not null "
                    + "and (:targetType is null or n.targetType = :targetType) "
                    + "and (:targetId is null or n.targetId = :targetId)")
    Page<Notification> findAdminActionHistory(@Param("targetType") NotificationTargetType targetType,
            @Param("targetId") String targetId, Pageable pageable);

    Optional<Notification> findByRecipient_UserIdAndSourceEventKey(Integer recipientId, String sourceEventKey);

    @Query("select n from Notification n where n.recipient.userId = :recipientId and n.type = :type "
            + "and n.targetType = Travel_Planner.Travel_Planner.model.enums.NotificationTargetType.POST "
            + "and n.targetId = :postId and n.readAt is null and n.sourceEventKey like concat(:eventPrefix, '%') "
            + "order by n.createdAt desc, n.notificationId desc")
    List<Notification> findUnreadLikeGroups(@Param("recipientId") Integer recipientId,
            @Param("postId") String postId, @Param("eventPrefix") String eventPrefix,
            @Param("type") NotificationType type, Pageable pageable);

    @Query("select n from Notification n left join fetch n.actor "
            + "where n.recipient.userId = :recipientId "
            + "and (:unreadOnly = false or n.readAt is null) "
            + "and (:type is null or n.type = :type or (:type = Travel_Planner.Travel_Planner.model.enums.NotificationType.SYSTEM "
            + "and n.type = Travel_Planner.Travel_Planner.model.enums.NotificationType.MODERATION_UPDATE)) "
            + "and (:cursorTime is null or n.createdAt < :cursorTime "
            + "or (n.createdAt = :cursorTime and n.notificationId < :cursorId)) "
            + "order by n.createdAt desc, n.notificationId desc")
    List<Notification> findFeed(@Param("recipientId") Integer recipientId,
            @Param("unreadOnly") boolean unreadOnly,
            @Param("type") NotificationType type,
            @Param("cursorTime") LocalDateTime cursorTime,
            @Param("cursorId") Long cursorId,
            org.springframework.data.domain.Pageable pageable);

    long countByRecipient_UserIdAndReadAtIsNull(Integer recipientId);

    @Query("select max(n.notificationId) from Notification n where n.recipient.userId = :recipientId")
    Long findLatestIdForRecipient(@Param("recipientId") Integer recipientId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Notification n set n.readAt = :readAt where n.notificationId = :id "
            + "and n.recipient.userId = :recipientId and n.readAt is null")
    int markRead(@Param("id") Long id, @Param("recipientId") Integer recipientId,
            @Param("readAt") LocalDateTime readAt);

    @Query("select count(n) > 0 from Notification n where n.notificationId = :id and n.recipient.userId = :recipientId")
    boolean existsForRecipient(@Param("id") Long id, @Param("recipientId") Integer recipientId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Notification n set n.readAt = :readAt where n.recipient.userId = :recipientId "
            + "and n.notificationId <= :maxId and n.readAt is null")
    int markAllReadThrough(@Param("recipientId") Integer recipientId, @Param("maxId") Long maxId,
            @Param("readAt") LocalDateTime readAt);
}
