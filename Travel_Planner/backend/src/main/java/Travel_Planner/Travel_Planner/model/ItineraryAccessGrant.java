package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.GrantStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "itinerary_access_grants",
        uniqueConstraints = @UniqueConstraint(name = "uk_itinerary_access_grants_pair", columnNames = {"itinerary_id", "grantee_user_id"}),
        indexes = {
                @Index(name = "idx_itinerary_access_grants_lookup", columnList = "itinerary_id,grantee_user_id,status"),
                @Index(name = "idx_itinerary_access_grants_grantee", columnList = "grantee_user_id,status")
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ItineraryAccessGrant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "grant_id")
    private Long grantId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "grantee_user_id", nullable = false)
    private User grantee;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "granted_by_user_id", nullable = false)
    private User grantedBy;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 16)
    @Builder.Default
    private GrantStatus status = GrantStatus.ACTIVE;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "revoked_at")
    private LocalDateTime revokedAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (status == null) {
            status = GrantStatus.ACTIVE;
        }
    }
}
