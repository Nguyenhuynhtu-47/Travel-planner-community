package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/announcements")
public class AnnouncementController {
    private final NotificationService notificationService;
    public AnnouncementController(NotificationService notificationService) { this.notificationService = notificationService; }

    @PostMapping("/{announcementId}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long announcementId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) throw new UnauthorizedException("Bạn cần đăng nhập để xem thông báo");
        notificationService.markAnnouncementRead(userDetails.getUsername(), announcementId);
        return ResponseEntity.noContent().build();
    }
}
