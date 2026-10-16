package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "itinerary_days", uniqueConstraints = {
    @UniqueConstraint(name = "uk_itinerary_day_number", columnNames = {"itinerary_id", "day_number"})
})
@Getter
@Setter
@Builder
public class ItineraryDay {

    public ItineraryDay() {
    }

    public ItineraryDay(Integer dayId, Itinerary itinerary, Integer dayNumber, String title,
                        LocalDate date, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.dayId = dayId;
        this.itinerary = itinerary;
        this.dayNumber = dayNumber;
        this.title = title;
        this.date = date;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "day_id")
    private Integer dayId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @Column(name = "day_number", nullable = false)
    private Integer dayNumber;

    @Column(name = "title", length = 150)
    private String title;

    @Column(name = "date")
    private LocalDate date;

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
