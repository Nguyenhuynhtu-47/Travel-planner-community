package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.UserDeviceToken;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import Travel_Planner.Travel_Planner.service.FcmMessageSender;
import Travel_Planner.Travel_Planner.service.NotificationPushListener;
import Travel_Planner.Travel_Planner.service.NotificationPushListener.AnnouncementEvent;
import Travel_Planner.Travel_Planner.service.NotificationPushListener.NotificationEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.scheduling.TaskScheduler;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationPushListenerTest {
    @Mock private FcmMessageSender sender;
    @Mock private UserDeviceTokenRepository tokens;
    @Mock private TaskScheduler scheduler;

    private NotificationPushListener listener;

    @BeforeEach
    void setUp() {
        listener = new NotificationPushListener(sender, tokens, scheduler);
    }

    @Test
    void sendsOrdinaryNotificationImmediately() {
        UserDeviceToken token = token(4L, "device-token");
        when(tokens.findAllByUser_UserIdAndDisabledAtIsNull(12)).thenReturn(List.of(token));

        listener.sendNotification(new NotificationEvent(12, 41L, "NEW_FOLLOWER",
                "Người theo dõi mới", "An đã theo dõi bạn", "USER", "8"));

        verify(sender).sendNotification(eq("device-token"), eq("Người theo dõi mới"),
                eq("An đã theo dõi bạn"), argThat(data -> "NOTIFICATION_PUSH".equals(data.get("type"))
                        && "41".equals(data.get("notificationId")) && "8".equals(data.get("targetId"))),
                isNull());
    }

    @Test
    void coalescesBurstLikesForTheSameRecipientAndPost() {
        UserDeviceToken token = token(5L, "like-token");
        when(tokens.findAllByUser_UserIdAndDisabledAtIsNull(12)).thenReturn(List.of(token));
        ArgumentCaptor<Runnable> scheduled = ArgumentCaptor.forClass(Runnable.class);

        listener.sendNotification(new NotificationEvent(12, 51L, "POST_LIKE",
                "Một lượt thích mới", null, "POST", "99"));
        listener.sendNotification(new NotificationEvent(12, 51L, "POST_LIKE",
                "Ba lượt thích mới", "Có nhiều người vừa thích", "POST", "99"));

        verify(scheduler, times(1)).schedule(scheduled.capture(), any(Instant.class));
        scheduled.getValue().run();

        verify(sender, times(1)).sendNotification(eq("like-token"), eq("Ba lượt thích mới"),
                eq("Có nhiều người vừa thích"), anyMap(),
                eq("notification-12-POST_LIKE-99"));
    }

    @Test
    void broadcastsPublishedAnnouncementToActiveDeviceTokens() {
        UserDeviceToken token = token(6L, "announcement-token");
        when(tokens.findTop200ByDisabledAtIsNullAndUser_StatusAndDeviceTokenIdGreaterThanOrderByDeviceTokenIdAsc(
                UserStatus.ACTIVE, 0L)).thenReturn(List.of(token));
        when(tokens.findTop200ByDisabledAtIsNullAndUser_StatusAndDeviceTokenIdGreaterThanOrderByDeviceTokenIdAsc(
                UserStatus.ACTIVE, 6L)).thenReturn(List.of());

        listener.sendAnnouncement(new AnnouncementEvent(7L, "Thông báo hệ thống", "Nội dung"));

        verify(sender).sendNotification(eq("announcement-token"), eq("Thông báo hệ thống"), eq("Nội dung"),
                argThat(data -> "ANNOUNCEMENT_PUSH".equals(data.get("type"))
                        && "7".equals(data.get("targetId"))), isNull());
    }

    private static UserDeviceToken token(Long id, String value) {
        UserDeviceToken token = new UserDeviceToken();
        token.setDeviceTokenId(id);
        token.setFcmToken(value);
        return token;
    }
}
