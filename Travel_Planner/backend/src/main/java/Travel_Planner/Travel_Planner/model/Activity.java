package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name = "activities", uniqueConstraints = {
    @UniqueConstraint(name = "uk_activity_day_order", columnNames = {"day_id", "display_order"})
})
@Getter
@Setter
@Builder
public class Activity {

    public Activity() {
    }

    public Activity(Integer activityId, ItineraryDay itineraryDay, Destination destination, String name,
                    String description, LocalTime startTime, LocalTime endTime, BigDecimal cost,
                    Integer displayOrder, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.activityId = activityId;
        this.itineraryDay = itineraryDay;
        this.destination = destination;
        this.name = name;
        this.description = description;
        this.startTime = startTime;
        this.endTime = endTime;
        this.cost = cost;
        this.displayOrder = displayOrder;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "activity_id")
    private Integer activityId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "day_id", nullable = false)
    private ItineraryDay itineraryDay;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "destination_id", nullable = false)
    private Destination destination;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "start_time")
    private LocalTime startTime;

    @Column(name = "end_time")
    private LocalTime endTime;

    @Column(name = "cost", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal cost = BigDecimal.ZERO;

    @Column(name = "display_order", nullable = false)
    private Integer displayOrder;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.cost == null) {
            this.cost = BigDecimal.ZERO;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
