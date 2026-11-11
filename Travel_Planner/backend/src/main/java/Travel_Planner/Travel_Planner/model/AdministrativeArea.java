package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.service.impl.LocationRankingServiceImpl;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "administrative_areas",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_admin_areas_code", columnNames = {"code"})
        },
        indexes = {
                @Index(name = "idx_admin_areas_parent_id", columnList = "parent_id"),
                @Index(name = "idx_admin_areas_normalized_name", columnList = "normalized_name"),
                @Index(name = "idx_admin_areas_type_status", columnList = "area_type, status"),
                @Index(name = "idx_admin_areas_trust_class", columnList = "trust_classification")
        }
)
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdministrativeArea {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "area_id")
    private Long areaId;

    /**
     * Official national administrative code (GSO / NSO code).
     * 2-digit string for provinces/central cities; 5-digit string for communes/wards.
     */
    @Column(name = "code", nullable = false, length = 20, unique = true)
    private String code;

    /**
     * Official administrative unit name (e.g. "Thành phố Hà Nội", "Phường Bến Nghé").
     */
    @Column(name = "name", nullable = false, length = 150)
    private String name;

    /**
     * Lowercased, diacritic-stripped search-friendly name.
     */
    @Column(name = "normalized_name", nullable = false, length = 150)
    private String normalizedName;

    /**
     * Administrative area type (PROVINCE, CENTRAL_CITY, COMMUNE, WARD, SPECIAL_ZONE).
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "area_type", nullable = false, length = 30)
    private AdministrativeAreaType areaType;

    /**
     * Parent administrative unit.
     * In Vietnam's 2-level model post 01/07/2025:
     * - Provinces and Central Cities have parent = null.
     * - Communes, Wards, Special Zones have parent pointing directly to their Province/Central City.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id", nullable = true)
    private AdministrativeArea parent;

    @OneToMany(mappedBy = "parent", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<AdministrativeArea> children = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private AdministrativeAreaStatus status = AdministrativeAreaStatus.ACTIVE;

    @Enumerated(EnumType.STRING)
    @Column(name = "trust_classification", nullable = false, length = 40)
    @Builder.Default
    private AdministrativeAreaTrustClassification trustClassification = AdministrativeAreaTrustClassification.VERIFIED_WITH_LIMITATIONS;

    @Column(name = "source", length = 50)
    @Builder.Default
    private String source = "GSO_2025";

    @Column(name = "effective_from")
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public void addChild(AdministrativeArea child) {
        if (this.children == null) {
            this.children = new ArrayList<>();
        }
        this.children.add(child);
        child.setParent(this);
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.status == null) {
            this.status = AdministrativeAreaStatus.ACTIVE;
        }
        if (this.trustClassification == null) {
            this.trustClassification = AdministrativeAreaTrustClassification.VERIFIED_WITH_LIMITATIONS;
        }
        if (this.source == null) {
            this.source = "GSO_2025";
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

