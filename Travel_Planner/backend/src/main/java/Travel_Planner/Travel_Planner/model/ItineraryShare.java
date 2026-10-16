package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "itinerary_shares")
@Getter
@Setter
@Builder
public class ItineraryShare {

    public ItineraryShare() {
    }

    public ItineraryShare(Integer shareId, Itinerary itinerary, String shareToken,
                          LocalDateTime createdAt, LocalDateTime expiresAt) {
        this.shareId = shareId;
        this.itinerary = itinerary;
        this.shareToken = shareToken;
        this.createdAt = createdAt;
        this.expiresAt = expiresAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "share_id")
    private Integer shareId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "share_token", nullable = false, unique = true, length = 255)
    private String shareToken;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
