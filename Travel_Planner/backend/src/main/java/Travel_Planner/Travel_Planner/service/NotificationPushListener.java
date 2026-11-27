package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.model.UserDeviceToken;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.Instant;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
@ConditionalOnProperty(name = "app.firebase.messaging.enabled", havingValue = "true")
public class NotificationPushListener {
    private static final Logger logger = LoggerFactory.getLogger(NotificationPushListener.class);
    private static final Duration COALESCE_WINDOW = Duration.ofSeconds(3);
    private static final Set<String> COALESCED_TYPES = Set.of(
            "POST_LIKE", "POST_COMMENT", "POST_COMMENT_REPLY",
            "ITINERARY_COMMENT", "ACTIVITY_COMMENT", "COMMENT_REPLY");

    private final FcmMessageSender sender;
    private final UserDeviceTokenRepository tokens;
    private final TaskScheduler scheduler;
    private final Map<String, NotificationEvent> pending = new ConcurrentHashMap<>();

    public NotificationPushListener(FcmMessageSender sender, UserDeviceTokenRepository tokens,
            TaskScheduler scheduler) {
        this.sender = sender;
        this.tokens = tokens;
        this.scheduler = scheduler;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendNotification(NotificationEvent event) {
        if (event.recipientUserId() == null || event.notificationId() == null) return;
        if (COALESCED_TYPES.contains(event.notificationType())) {
            String key = coalesceKey(event);
            NotificationEvent previous = pending.put(key, event);
            if (previous == null) {
                scheduler.schedule(() -> sendPending(key), Instant.now().plus(COALESCE_WINDOW));
            }
            return;
        }
        deliver(event, null);
    }

    private void sendPending(String key) {
        NotificationEvent event = pending.remove(key);
        if (event != null) deliver(event, key);
    }

    private void deliver(NotificationEvent event, String collapseKey) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "NOTIFICATION_PUSH");
        data.put("notificationId", event.notificationId().toString());
        putIfPresent(data, "notificationType", event.notificationType());
        putIfPresent(data, "targetType", event.targetType());
        putIfPresent(data, "targetId", event.targetId());
        for (UserDeviceToken token : tokens.findAllByUser_UserIdAndDisabledAtIsNull(event.recipientUserId())) {
            send(token, event.title(), event.body(), data, collapseKey);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendAnnouncement(AnnouncementEvent event) {
        if (event.announcementId() == null) return;
        Map<String, String> data = Map.of(
                "type", "ANNOUNCEMENT_PUSH",
                "targetType", "ANNOUNCEMENT",
                "targetId", event.announcementId().toString());
        long lastTokenId = 0L;
        java.util.List<UserDeviceToken> batch;
        do {
            batch = tokens
                    .findTop200ByDisabledAtIsNullAndUser_StatusAndDeviceTokenIdGreaterThanOrderByDeviceTokenIdAsc(
                            UserStatus.ACTIVE, lastTokenId);
            for (UserDeviceToken token : batch) {
                lastTokenId = token.getDeviceTokenId();
                send(token, event.title(), event.body(), data, null);
            }
        } while (!batch.isEmpty());
    }

    private void send(UserDeviceToken token, String title, String body, Map<String, String> data,
            String collapseKey) {
        try {
            sender.sendNotification(token.getFcmToken(), title, body, data, collapseKey);
        } catch (RuntimeException exception) {
            if (sender.isInvalidRegistration(exception)) tokens.disable(token.getDeviceTokenId());
            logger.warn("FCM notification push failed for device token id {}", token.getDeviceTokenId());
        }
    }

    private static void putIfPresent(Map<String, String> data, String key, String value) {
        if (value != null && !value.isBlank()) data.put(key, value);
    }

    private static String coalesceKey(NotificationEvent event) {
        String family = switch (event.notificationType()) {
            case "POST_COMMENT", "POST_COMMENT_REPLY" -> "POST_COMMENT";
            case "ITINERARY_COMMENT", "ACTIVITY_COMMENT", "COMMENT_REPLY" -> "ITINERARY_COMMENT";
            default -> event.notificationType();
        };
        return "notification-" + event.recipientUserId() + "-" + family + "-"
                + (event.targetId() == null ? event.notificationId() : event.targetId());
    }

    public record NotificationEvent(Integer recipientUserId, Long notificationId,
            String notificationType, String title, String body, String targetType, String targetId) {
    }

    public record AnnouncementEvent(Long announcementId, String title, String body) {
    }
}
