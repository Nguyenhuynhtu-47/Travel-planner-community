package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.model.enums.NotificationActionType;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "notifications", indexes = {
        @Index(name = "idx_notifications_recipient_created", columnList = "recipient_user_id, created_at, notification_id"),
        @Index(name = "idx_notifications_recipient_read_created", columnList = "recipient_user_id, read_at, created_at"),
        @Index(name = "idx_notifications_action_target_created", columnList = "action_type, target_type, target_id, created_at, notification_id")
}, uniqueConstraints = {
        @UniqueConstraint(name = "uk_notifications_recipient_event", columnNames = {"recipient_user_id", "source_event_key"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_id")
    private Long notificationId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipient_user_id", nullable = false)
    private User recipient;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_user_id")
    private User actor;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 40)
    private NotificationType type;

    @Enumerated(EnumType.STRING)
    @Column(name = "action_type", length = 40)
    private NotificationActionType actionType;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", length = 24)
    private NotificationTargetType targetType;

    /** Target identifiers are strings because source domains use both Integer and Long IDs. */
    @Column(name = "target_id", length = 100)
    private String targetId;

    @Column(name = "source_event_key", length = 191)
    private String sourceEventKey;

    @Column(name = "title", nullable = false, length = 160)
    private String title;

    @Column(name = "body", length = 500)
    private String body;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
