package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "post_media",
        indexes = {
                @Index(name = "idx_post_media_post_order", columnList = "post_id,display_order")
        },
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_post_media_asset", columnNames = {"media_asset_id"})
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostMedia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "post_media_id")
    private Long postMediaId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "media_asset_id", nullable = false)
    private MediaAsset mediaAsset;

    @Column(name = "display_order", nullable = false)
    @Builder.Default
    private Integer displayOrder = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (displayOrder == null) displayOrder = 0;
    }
}

