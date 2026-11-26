package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.NotificationPageResponse;
import Travel_Planner.Travel_Planner.dto.response.UnreadCountResponse;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.service.NotificationService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/notifications")
@Validated
public class NotificationController {
    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<NotificationPageResponse> getFeed(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") @Min(1) @Max(50) int size,
            @RequestParam(defaultValue = "false") boolean unreadOnly,
            @RequestParam(required = false) NotificationType type,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(notificationService.getFeed(requireUsername(userDetails), cursor, size, unreadOnly, type));
    }

    @GetMapping("/unread-count")
    public ResponseEntity<UnreadCountResponse> getUnreadCount(
            @AuthenticationPrincipal UserDetails userDetails) {
        String username = requireUsername(userDetails);
        long personalCount = notificationService.getPersonalUnreadCount(username);
        long announcementCount = notificationService.getAnnouncementUnreadCount(username);
        return ResponseEntity.ok(new UnreadCountResponse(personalCount + announcementCount, personalCount, announcementCount));
    }

    @PostMapping("/{notificationId}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long notificationId,
            @AuthenticationPrincipal UserDetails userDetails) {
        notificationService.markRead(requireUsername(userDetails), notificationId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/read-all")
    public ResponseEntity<Void> markAllRead(@AuthenticationPrincipal UserDetails userDetails) {
        notificationService.markAllRead(requireUsername(userDetails));
        return ResponseEntity.noContent().build();
    }

    private static String requireUsername(UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để xem thông báo");
        }
        return userDetails.getUsername();
    }
}
