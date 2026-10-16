package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "itineraries")
@Getter
@Setter
@Builder
public class Itinerary {

    public Itinerary() {
    }

    public Itinerary(Integer itineraryId, User user, Itinerary originalItinerary, String title,
                     String description, String location, Integer totalDays, BigDecimal budget,
                     String theme, Visibility visibility, ItineraryStatus status, Integer viewCount,
                     Integer favoriteCount, Integer ratingCount, Integer commentCount, Integer reuseCount,
                     LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.itineraryId = itineraryId;
        this.user = user;
        this.originalItinerary = originalItinerary;
        this.title = title;
        this.description = description;
        this.location = location;
        this.totalDays = totalDays;
        this.budget = budget;
        this.theme = theme;
        this.visibility = visibility;
        this.status = status;
        this.viewCount = viewCount;
        this.favoriteCount = favoriteCount;
        this.ratingCount = ratingCount;
        this.commentCount = commentCount;
        this.reuseCount = reuseCount;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "itinerary_id")
    private Integer itineraryId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "original_itinerary_id")
    private Itinerary originalItinerary;

    @Column(name = "title", nullable = false, length = 150)
    private String title;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "location", nullable = false, length = 150)
    private String location;

    @Column(name = "total_days", nullable = false)
    private Integer totalDays;

    @Column(name = "budget", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal budget = BigDecimal.ZERO;

    @Column(name = "theme", length = 100)
    private String theme;

    @Enumerated(EnumType.STRING)
    @Column(name = "visibility", nullable = false, length = 20)
    @Builder.Default
    private Visibility visibility = Visibility.PRIVATE;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private ItineraryStatus status = ItineraryStatus.ACTIVE;

    @Column(name = "view_count", nullable = false)
    @Builder.Default
    private Integer viewCount = 0;

    @Column(name = "favorite_count", nullable = false)
    @Builder.Default
    private Integer favoriteCount = 0;

    @Column(name = "rating_count", nullable = false)
    @Builder.Default
    private Integer ratingCount = 0;

    @Column(name = "comment_count", nullable = false)
    @Builder.Default
    private Integer commentCount = 0;

    @Column(name = "reuse_count", nullable = false)
    @Builder.Default
    private Integer reuseCount = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.budget == null) {
            this.budget = BigDecimal.ZERO;
        }
        if (this.visibility == null) {
            this.visibility = Visibility.PRIVATE;
        }
        if (this.status == null) {
            this.status = ItineraryStatus.ACTIVE;
        }
        if (this.viewCount == null) {
            this.viewCount = 0;
        }
        if (this.favoriteCount == null) {
            this.favoriteCount = 0;
        }
        if (this.ratingCount == null) {
            this.ratingCount = 0;
        }
        if (this.commentCount == null) {
            this.commentCount = 0;
        }
        if (this.reuseCount == null) {
            this.reuseCount = 0;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
