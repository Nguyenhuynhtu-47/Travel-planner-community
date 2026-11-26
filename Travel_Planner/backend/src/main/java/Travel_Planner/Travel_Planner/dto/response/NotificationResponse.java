package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.Notification;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class NotificationResponse {
    private Long id;
    private String type;
    private String actionType;
    private String title;
    private String body;
    private String targetType;
    private String targetId;
    private NotificationActorResponse actor;
    private LocalDateTime createdAt;
    private LocalDateTime readAt;
    private boolean announcement;

    public static NotificationResponse from(Notification notification) {
        NotificationActorResponse actorResponse = null;
        if (notification.getActor() != null) {
            actorResponse = NotificationActorResponse.builder()
                    .userId(notification.getActor().getUserId())
                    .username(notification.getActor().getUsername())
                    .handle(notification.getActor().getHandle())
                    .displayName(notification.getActor().getFullName())
                    .avatar(notification.getActor().getAvatar())
                    .build();
        }
        return NotificationResponse.builder()
                .id(notification.getNotificationId())
                .type(notification.getType() == NotificationType.MODERATION_UPDATE
                        ? NotificationType.SYSTEM.name() : notification.getType().name())
                .actionType(notification.getActionType() == null ? null : notification.getActionType().name())
                .title(notification.getTitle())
                .body(notification.getBody())
                .targetType(notification.getTargetType() == null ? null : notification.getTargetType().name())
                .targetId(notification.getTargetId())
                .actor(actorResponse)
                .createdAt(notification.getCreatedAt())
                .readAt(notification.getReadAt())
                .announcement(false)
                .build();
    }

    public static NotificationResponse fromAnnouncement(Travel_Planner.Travel_Planner.model.SystemAnnouncement announcement,
            LocalDateTime readAt) {
        return NotificationResponse.builder()
                .id(announcement.getAnnouncementId())
                .type("SYSTEM")
                .title(announcement.getTitle())
                .body(announcement.getBody())
                .targetType("ANNOUNCEMENT")
                .targetId(announcement.getAnnouncementId().toString())
                .createdAt(announcement.getPublishedAt())
                .readAt(readAt)
                .announcement(true)
                .build();
    }
}
