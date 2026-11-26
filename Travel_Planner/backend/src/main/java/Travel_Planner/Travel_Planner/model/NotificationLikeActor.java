package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.LocalDateTime;

@Entity
@Table(name = "notification_like_actors", uniqueConstraints = {
        @UniqueConstraint(name = "uk_notification_like_actor", columnNames = {"notification_id", "actor_user_id"})
}, indexes = {
        @Index(name = "idx_notification_like_actor_user", columnList = "actor_user_id, notification_id")
})
@Getter
@Setter
@NoArgsConstructor
public class NotificationLikeActor {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_like_actor_id")
    private Long notificationLikeActorId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "notification_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_notification_like_actor_notification"))
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Notification notification;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "actor_user_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_notification_like_actor_user"))
    private User actor;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now(java.time.ZoneOffset.UTC);
    }
}
