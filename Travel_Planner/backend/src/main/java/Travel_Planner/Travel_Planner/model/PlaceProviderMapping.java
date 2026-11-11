package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "place_provider_mappings",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_provider_place_id", columnNames = {"provider", "provider_place_id"})
        },
        indexes = {
                @Index(name = "idx_mapping_place_id", columnList = "place_id"),
                @Index(name = "idx_mapping_provider_id", columnList = "provider, provider_place_id")
        }
)
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceProviderMapping {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "mapping_id")
    private Long mappingId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "place_id", nullable = false)
    private Place place;

    @Column(name = "provider", nullable = false, length = 50)
    private String provider;

    @Column(name = "provider_place_id", nullable = false, length = 255)
    private String providerPlaceId;

    @Column(name = "provider_type", length = 50)
    private String providerType;

    @Column(name = "metadata_json", columnDefinition = "TEXT")
    private String metadataJson;

    @Column(name = "last_synced_at", nullable = false)
    private LocalDateTime lastSyncedAt;

    @PrePersist
    @PreUpdate
    protected void onSave() {
        if (this.lastSyncedAt == null) {
            this.lastSyncedAt = LocalDateTime.now();
        }
    }
}

