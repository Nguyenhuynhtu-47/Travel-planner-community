package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.NotificationLikeActor;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationLikeActorRepository extends JpaRepository<NotificationLikeActor, Long> {
    boolean existsByNotification_NotificationIdAndActor_UserId(Long notificationId, Integer actorId);

    long countByNotification_NotificationId(Long notificationId);

    NotificationLikeActor findFirstByNotification_NotificationIdOrderByCreatedAtDescNotificationLikeActorIdDesc(
            Long notificationId);

    @Query("select a from NotificationLikeActor a join fetch a.notification n join fetch a.actor u "
            + "where n.recipient.userId = :recipientId and n.type = :type and n.targetId = :postId "
            + "and n.readAt is null and u.userId = :actorId")
    List<NotificationLikeActor> findUnreadMemberships(@Param("recipientId") Integer recipientId,
            @Param("postId") String postId, @Param("actorId") Integer actorId,
            @Param("type") NotificationType type);
}
