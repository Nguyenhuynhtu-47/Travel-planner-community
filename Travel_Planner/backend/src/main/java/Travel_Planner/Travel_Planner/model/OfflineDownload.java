package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "offline_downloads")
@Getter
@Setter
@Builder
public class OfflineDownload {

    public OfflineDownload() {
    }

    public OfflineDownload(Integer downloadId, User user, Itinerary itinerary, LocalDateTime downloadedAt) {
        this.downloadId = downloadId;
        this.user = user;
        this.itinerary = itinerary;
        this.downloadedAt = downloadedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "download_id")
    private Integer downloadId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "downloaded_at", nullable = false, updatable = false)
    private LocalDateTime downloadedAt;

    @PrePersist
    protected void onCreate() {
        this.downloadedAt = LocalDateTime.now();
    }
}
