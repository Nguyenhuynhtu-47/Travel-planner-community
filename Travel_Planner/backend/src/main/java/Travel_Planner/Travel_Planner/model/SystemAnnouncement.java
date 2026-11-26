package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "system_announcements", indexes = {
        @Index(name = "idx_announcement_status_window", columnList = "status, published_at, expires_at")
})
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SystemAnnouncement {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "announcement_id")
    private Long announcementId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id")
    private User createdBy;

    @Column(nullable = false, length = 160)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    /** Legacy non-null schema column; all announcements now belong to one SYSTEM group. */
    @Column(nullable = false, length = 24)
    private String type;

    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 24)
    @Builder.Default private AnnouncementStatus status = AnnouncementStatus.DRAFT;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    @Column(name = "published_at") private LocalDateTime publishedAt;
    @Column(name = "expires_at") private LocalDateTime expiresAt;

    @PrePersist protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        type = "SYSTEM";
        updatedAt = now;
    }
    @PreUpdate protected void onUpdate() { type = "SYSTEM"; updatedAt = LocalDateTime.now(); }
}
