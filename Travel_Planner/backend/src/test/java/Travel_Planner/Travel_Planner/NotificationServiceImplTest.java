package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Notification;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.service.NotificationPushListener.NotificationEvent;
import Travel_Planner.Travel_Planner.repository.NotificationRepository;
import Travel_Planner.Travel_Planner.repository.NotificationLikeActorRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.SystemAnnouncementRepository;
import Travel_Planner.Travel_Planner.repository.AnnouncementReadRepository;
import Travel_Planner.Travel_Planner.service.impl.NotificationServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationServiceImplTest {
    @Mock private NotificationRepository notificationRepository;
    @Mock private NotificationLikeActorRepository likeActorRepository;
    @Mock private UserRepository userRepository;
    @Mock private SystemAnnouncementRepository announcementRepository;
    @Mock private AnnouncementReadRepository announcementReadRepository;
    @Mock private ApplicationEventPublisher events;

    private NotificationServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new NotificationServiceImpl(notificationRepository, likeActorRepository, userRepository,
                announcementRepository, announcementReadRepository, events);
    }

    @Test
    void createReturnsExistingNotificationForRepeatedEventKey() {
        User recipient = user(10, "recipient");
        Notification existing = Notification.builder().notificationId(41L).build();
        when(userRepository.findByUserIdForUpdate(10)).thenReturn(Optional.of(recipient));
        when(notificationRepository.findByRecipient_UserIdAndSourceEventKey(10, "follow:22:10"))
                .thenReturn(Optional.of(existing));

        Optional<Notification> result = service.create(10, 22, NotificationType.NEW_FOLLOWER,
                "Có người theo dõi bạn", null, null, null, "follow:22:10");

        assertEquals(existing, result.orElseThrow());
        verify(notificationRepository, never()).save(any());
    }

    @Test
    void createSkipsSelfNotifications() {
        when(userRepository.findByUserIdForUpdate(10)).thenReturn(Optional.of(user(10, "same")));

        assertTrue(service.create(10, 10, NotificationType.NEW_FOLLOWER,
                "Tự theo dõi", null, null, null, "follow:10:10").isEmpty());
        verify(notificationRepository, never()).save(any());
    }

    @Test
    void createPublishesPushEventOnlyForANewNotification() {
        User recipient = user(10, "recipient");
        User actor = user(22, "actor");
        when(userRepository.findByUserIdForUpdate(10)).thenReturn(Optional.of(recipient));
        when(userRepository.findById(22)).thenReturn(Optional.of(actor));
        when(notificationRepository.findByRecipient_UserIdAndSourceEventKey(10, "follow:22"))
                .thenReturn(Optional.empty());
        when(notificationRepository.save(any(Notification.class))).thenAnswer(invocation -> {
            Notification saved = invocation.getArgument(0);
            saved.setNotificationId(71L);
            return saved;
        });

        service.create(10, 22, NotificationType.NEW_FOLLOWER, "Có người theo dõi", "Actor theo dõi bạn",
                NotificationTargetType.USER, "22", "follow:22");

        ArgumentCaptor<Object> event = ArgumentCaptor.forClass(Object.class);
        verify(events).publishEvent(event.capture());
        NotificationEvent push = assertInstanceOf(NotificationEvent.class, event.getValue());
        assertEquals(71L, push.notificationId());
        assertEquals(10, push.recipientUserId());
    }

    @Test
    void feedUsesPrincipalAndStableCursorAndReturnsOnlyRequestedPage() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user(10, "alice")));
        LocalDateTime now = LocalDateTime.of(2026, 11, 26, 10, 0);
        List<Notification> fetched = List.of(
                notification(3L, now), notification(2L, now.minusMinutes(1)), notification(1L, now.minusMinutes(2)));
        when(notificationRepository.findFeed(eq(10), eq(true), isNull(), isNull(), isNull(), any())).thenReturn(fetched);
        when(announcementRepository.findUnreadActive(eq(10), any(), any())).thenReturn(List.of());

        var page = service.getFeed("alice", null, 2, true, null);

        assertEquals(2, page.getContent().size());
        assertTrue(page.isHasMore());
        assertNotNull(page.getNextCursor());
        verify(notificationRepository).findFeed(eq(10), eq(true), isNull(), isNull(), isNull(), any());
    }

    @Test
    void feedRejectsMalformedCursor() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user(10, "alice")));
        assertThrows(BadRequestException.class, () -> service.getFeed("alice", "not-a-cursor", 20, false, null));
        verifyNoInteractions(notificationRepository);
    }

    @Test
    void markReadDoesNotRevealAnotherUsersNotification() {
        when(userRepository.findByUsernameForUpdate("alice")).thenReturn(Optional.of(user(10, "alice")));
        when(notificationRepository.markRead(eq(9L), eq(10), any(LocalDateTime.class))).thenReturn(0);
        when(notificationRepository.existsForRecipient(9L, 10)).thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () -> service.markRead("alice", 9L));
        verify(notificationRepository).markRead(eq(9L), eq(10), any(LocalDateTime.class));
    }

    @Test
    void markAllReadUsesRecipientWatermark() {
        when(userRepository.findByUsernameForUpdate("alice")).thenReturn(Optional.of(user(10, "alice")));
        when(notificationRepository.findLatestIdForRecipient(10)).thenReturn(100L);
        when(notificationRepository.markAllReadThrough(eq(10), eq(100L), any(LocalDateTime.class))).thenReturn(8);

        assertEquals(8, service.markAllRead("alice"));
        verify(notificationRepository).markAllReadThrough(eq(10), eq(100L), any(LocalDateTime.class));
    }

    private static User user(Integer id, String username) {
        return User.builder().userId(id).username(username).handle(username).fullName(username).build();
    }

    private static Notification notification(Long id, LocalDateTime createdAt) {
        return Notification.builder().notificationId(id).type(NotificationType.NEW_FOLLOWER)
                .title("Follow").createdAt(createdAt).build();
    }
}
