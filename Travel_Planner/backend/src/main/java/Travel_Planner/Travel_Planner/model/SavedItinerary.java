package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "saved_itineraries", uniqueConstraints = {
    @UniqueConstraint(name = "uk_saved_user_itinerary", columnNames = {"user_id", "itinerary_id"})
})
@Getter
@Setter
@Builder
public class SavedItinerary {

    public SavedItinerary() {
    }

    public SavedItinerary(Integer saveId, User user, Itinerary itinerary, LocalDateTime createdAt) {
        this.saveId = saveId;
        this.user = user;
        this.itinerary = itinerary;
        this.createdAt = createdAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "save_id")
    private Integer saveId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
