package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "destinations")
@Getter
@Setter
@Builder
public class Destination {

    public Destination() {
    }

    public Destination(Integer destinationId, String name, String address, String description,
                       String imageUrl, BigDecimal latitude, BigDecimal longitude, DestinationStatus status,
                       LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.destinationId = destinationId;
        this.name = name;
        this.address = address;
        this.description = description;
        this.imageUrl = imageUrl;
        this.latitude = latitude;
        this.longitude = longitude;
        this.status = status;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "destination_id")
    private Integer destinationId;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "address", nullable = false, length = 255)
    private String address;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private DestinationStatus status = DestinationStatus.ACTIVE;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.status == null) {
            this.status = DestinationStatus.ACTIVE;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
