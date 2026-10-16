package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "ratings", uniqueConstraints = {
    @UniqueConstraint(name = "uk_rating_user_itinerary", columnNames = {"user_id", "itinerary_id"})
})
@Getter
@Setter
@Builder
public class Rating {

    public Rating() {
    }

    public Rating(Integer ratingId, User user, Itinerary itinerary, Integer score,
                  LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.ratingId = ratingId;
        this.user = user;
        this.itinerary = itinerary;
        this.score = score;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "rating_id")
    private Integer ratingId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "score", nullable = false)
    private Integer score;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
