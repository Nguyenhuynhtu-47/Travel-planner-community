package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name = "activities",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_activity_day_order", columnNames = {"day_id", "display_order"})
    },
    indexes = {
        @Index(name = "idx_activities_coordinates", columnList = "latitude, longitude")
    }
)
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Activity {

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
    @JoinColumn(name = "destination_id", nullable = true)
    private Destination destination;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "location_name", length = 150)
    private String locationName;

    @Column(name = "location_address", length = 255)
    private String locationAddress;

    @Column(name = "custom_location_name", length = 150)
    private String customLocationName;

    @Column(name = "custom_address", length = 255)
    private String customAddress;

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "place_id", length = 100)
    private String placeId;

    @Column(name = "location_provider", length = 30)
    private String locationProvider;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

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
        syncLocationFields();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
        syncLocationFields();
    }

    public void syncLocationFields() {
        // Authoritative source of truth is locationName / locationAddress.
        // Legacy custom_* columns mirror authoritative fields for database-level backward compatibility.
        if (this.locationName != null) {
            this.customLocationName = this.locationName;
        } else if (this.customLocationName != null) {
            this.locationName = this.customLocationName;
        } else {
            this.customLocationName = null;
        }

        if (this.locationAddress != null) {
            this.customAddress = this.locationAddress;
        } else if (this.customAddress != null) {
            this.locationAddress = this.customAddress;
        } else {
            this.customAddress = null;
        }
    }
}
