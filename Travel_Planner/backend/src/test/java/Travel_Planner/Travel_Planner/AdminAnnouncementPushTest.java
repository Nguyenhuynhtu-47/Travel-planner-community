package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.SystemAnnouncement;
import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import Travel_Planner.Travel_Planner.repository.SystemAnnouncementRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.NotificationPushListener.AnnouncementEvent;
import Travel_Planner.Travel_Planner.service.impl.AdminAnnouncementServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.ArgumentCaptor;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminAnnouncementPushTest {
    @Mock private SystemAnnouncementRepository announcements;
    @Mock private UserRepository users;
    @Mock private AuditLogService audit;
    @Mock private ApplicationEventPublisher events;

    @Test
    void publishingAnnouncementEmitsPushAfterTheTransactionCommits() {
        SystemAnnouncement announcement = SystemAnnouncement.builder()
                .announcementId(9L)
                .title("Thông báo hệ thống")
                .body("Nội dung quan trọng")
                .status(AnnouncementStatus.DRAFT)
                .expiresAt(LocalDateTime.now().plusDays(1))
                .build();
        when(announcements.findByIdForUpdate(9L)).thenReturn(Optional.of(announcement));
        AdminAnnouncementServiceImpl service = new AdminAnnouncementServiceImpl(
                announcements, users, audit, events);

        service.publish(9L, "admin");

        ArgumentCaptor<Object> event = ArgumentCaptor.forClass(Object.class);
        verify(events).publishEvent(event.capture());
        AnnouncementEvent push = assertInstanceOf(AnnouncementEvent.class, event.getValue());
        assertEquals(9L, push.announcementId());
        assertEquals("Thông báo hệ thống", push.title());
    }

    @Test
    void scheduledAnnouncementIsPublishedOnceWhenItsTimeArrives() {
        SystemAnnouncement announcement = SystemAnnouncement.builder()
                .announcementId(10L)
                .title("Thông báo theo lịch")
                .body("Nội dung")
                .status(AnnouncementStatus.DRAFT)
                .publishedAt(LocalDateTime.now().minusMinutes(1))
                .expiresAt(LocalDateTime.now().plusDays(1))
                .build();
        when(announcements.findExpiredForUpdate(org.mockito.ArgumentMatchers.any()))
                .thenReturn(List.of());
        when(announcements.findScheduledForUpdate(org.mockito.ArgumentMatchers.any()))
                .thenReturn(List.of(announcement));
        AdminAnnouncementServiceImpl service = new AdminAnnouncementServiceImpl(
                announcements, users, audit, events);

        service.synchronizeLifecycle();

        assertEquals(AnnouncementStatus.PUBLISHED, announcement.getStatus());
        verify(events).publishEvent(org.mockito.ArgumentMatchers.any(AnnouncementEvent.class));
    }

    @Test
    void expiredAnnouncementIsCancelledBeforeScheduledPublication() {
        SystemAnnouncement announcement = SystemAnnouncement.builder()
                .announcementId(11L)
                .title("Thông báo hết hạn")
                .body("Nội dung")
                .status(AnnouncementStatus.DRAFT)
                .publishedAt(LocalDateTime.now().minusMinutes(2))
                .expiresAt(LocalDateTime.now().minusMinutes(1))
                .build();
        when(announcements.findExpiredForUpdate(org.mockito.ArgumentMatchers.any()))
                .thenReturn(List.of(announcement));
        when(announcements.findScheduledForUpdate(org.mockito.ArgumentMatchers.any()))
                .thenReturn(List.of());
        AdminAnnouncementServiceImpl service = new AdminAnnouncementServiceImpl(
                announcements, users, audit, events);

        service.synchronizeLifecycle();

        assertEquals(AnnouncementStatus.CANCELLED, announcement.getStatus());
    }
}
