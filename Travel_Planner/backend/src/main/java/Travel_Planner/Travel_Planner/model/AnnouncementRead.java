package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;
import java.io.Serializable;
import java.time.LocalDateTime;

@Entity
@Table(name = "announcement_reads", indexes = {
        @Index(name = "idx_announcement_reads_user_announcement", columnList = "user_id, announcement_id")
})
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AnnouncementRead {
    @EmbeddedId private Id id;
    @MapsId("announcementId") @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "announcement_id") private SystemAnnouncement announcement;
    @MapsId("userId") @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id") private User user;
    @Column(name = "read_at", nullable = false) private LocalDateTime readAt;

    @Embeddable @Getter @Setter @NoArgsConstructor @AllArgsConstructor @EqualsAndHashCode
    public static class Id implements Serializable {
        @Column(name = "announcement_id") private Long announcementId;
        @Column(name = "user_id") private Integer userId;
    }
}
