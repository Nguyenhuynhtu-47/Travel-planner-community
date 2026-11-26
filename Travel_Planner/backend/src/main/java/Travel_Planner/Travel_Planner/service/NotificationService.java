package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.NotificationPageResponse;
import Travel_Planner.Travel_Planner.dto.response.NotificationResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.model.Notification;
import Travel_Planner.Travel_Planner.model.Post;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.model.enums.NotificationActionType;

import java.util.Optional;

public interface NotificationService {

    /** Internal domain-service seam. No client-facing create endpoint is exposed. */
    Optional<Notification> create(Integer recipientUserId, Integer actorUserId,
            NotificationType type, String title, String body,
            NotificationTargetType targetType, String targetId, String sourceEventKey);

    Optional<Notification> createAdminAction(Integer recipientUserId, Integer adminUserId,
            NotificationActionType actionType, String title, String body,
            NotificationTargetType targetType, String targetId, String sourceEventKey);

    Optional<Notification> recordPostLike(User recipient, User actor, Post post);

    void removePostLikeFromUnreadGroup(User recipient, User actor, Post post);

    NotificationPageResponse getFeed(String username, String cursor, int size,
            boolean unreadOnly, NotificationType type);

    long getUnreadCount(String username);

    long getPersonalUnreadCount(String username);

    long getAnnouncementUnreadCount(String username);

    void markRead(String username, Long notificationId);

    int markAllRead(String username);

    void markAnnouncementRead(String username, Long announcementId);

    PageResponse<NotificationResponse> getAdminActionHistory(NotificationTargetType targetType,
            String targetId, int page, int size);
}
