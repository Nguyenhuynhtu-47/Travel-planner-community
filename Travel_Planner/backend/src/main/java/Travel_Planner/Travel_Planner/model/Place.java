package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "places", indexes = {
        @Index(name = "idx_places_normalized_name", columnList = "normalized_name"),
        @Index(name = "idx_places_category", columnList = "category"),
        @Index(name = "idx_places_status", columnList = "status"),
        @Index(name = "idx_places_coords", columnList = "latitude, longitude"),
        @Index(name = "idx_places_source_dest", columnList = "source_destination_id")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Place {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "place_id")
    private Long placeId;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "normalized_name", nullable = false, length = 150)
    private String normalizedName;

    @Column(name = "address", nullable = false, length = 255)
    private String address;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "latitude", precision = 10, scale = 7, nullable = false)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7, nullable = false)
    private BigDecimal longitude;

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 50)
    @Builder.Default
    private PlaceCategory category = PlaceCategory.ATTRACTION;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private PlaceStatus status = PlaceStatus.ACTIVE;

    @Column(name = "source_destination_id")
    private Integer sourceDestinationId;

    @OneToMany(mappedBy = "place", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<PlaceProviderMapping> providerMappings = new ArrayList<>();

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public void addProviderMapping(PlaceProviderMapping mapping) {
        if (this.providerMappings == null) {
            this.providerMappings = new ArrayList<>();
        }
        this.providerMappings.add(mapping);
        mapping.setPlace(this);
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.status == null) {
            this.status = PlaceStatus.ACTIVE;
        }
        if (this.category == null) {
            this.category = PlaceCategory.ATTRACTION;
        }
        if (this.normalizedName == null && this.name != null) {
            this.normalizedName = LocationRankingServiceImpl.normalizeText(this.name);
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
        if (this.name != null) {
            this.normalizedName = LocationRankingServiceImpl.normalizeText(this.name);
        }
    }
}

