package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.SystemAnnouncement;
import lombok.Builder;
import lombok.Getter;
import java.time.LocalDateTime;

@Getter @Builder
public class AdminAnnouncementResponse {
    private Long id;
    private String title;
    private String body;
    private String type;
    private String status;
    private String createdBy;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime publishedAt;
    private LocalDateTime expiresAt;

    public static AdminAnnouncementResponse from(SystemAnnouncement a) {
        return AdminAnnouncementResponse.builder().id(a.getAnnouncementId()).title(a.getTitle()).body(a.getBody())
                .type("SYSTEM").status(a.getStatus().name())
                .createdBy(a.getCreatedBy() == null ? null : a.getCreatedBy().getUsername())
                .createdAt(a.getCreatedAt()).updatedAt(a.getUpdatedAt()).publishedAt(a.getPublishedAt())
                .expiresAt(a.getExpiresAt()).build();
    }
}
