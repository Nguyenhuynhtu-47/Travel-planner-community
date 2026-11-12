package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "media_assets",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_media_assets_public_id", columnNames = {"cloudinary_public_id"})
        },
        indexes = {
                @Index(name = "idx_media_assets_owner_status", columnList = "uploaded_by,status,created_at"),
                @Index(name = "idx_media_assets_cleanup", columnList = "status,dead_lettered_at,next_retry_at,locked_at")
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MediaAsset {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "media_asset_id")
    private Long mediaAssetId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "uploaded_by", nullable = false)
    private User uploadedBy;

    @Column(name = "cloudinary_public_id", nullable = false, length = 255)
    private String cloudinaryPublicId;

    @Column(name = "secure_url", nullable = false, length = 500)
    private String secureUrl;

    @Column(name = "media_type", nullable = false, length = 50)
    @Builder.Default
    private String mediaType = "IMAGE";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private MediaAssetStatus status = MediaAssetStatus.UNATTACHED;

    @Column(name = "claim_token", length = 36)
    private String claimToken;

    @Column(name = "locked_at")
    private LocalDateTime lockedAt;

    @Column(name = "locked_by", length = 100)
    private String lockedBy;

    @Column(name = "retry_count", nullable = false)
    @Builder.Default
    private Integer retryCount = 0;

    @Column(name = "next_retry_at")
    private LocalDateTime nextRetryAt;

    @Column(name = "dead_lettered_at")
    private LocalDateTime deadLetteredAt;

    @Column(name = "last_error", length = 500)
    private String lastError;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        if (updatedAt == null) updatedAt = now;
        if (mediaType == null) mediaType = "IMAGE";
        if (status == null) status = MediaAssetStatus.UNATTACHED;
        if (retryCount == null) retryCount = 0;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

