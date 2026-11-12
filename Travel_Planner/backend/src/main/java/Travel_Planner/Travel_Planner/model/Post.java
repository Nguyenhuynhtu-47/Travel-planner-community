package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.PostVisibility;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "posts",
        indexes = {
                @Index(name = "idx_posts_feed_public", columnList = "status,visibility,created_at,post_id"),
                @Index(name = "idx_posts_author", columnList = "author_id,status,created_at")
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Post {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "post_id")
    private Long postId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id")
    private Itinerary itinerary;

    @Column(name = "content", columnDefinition = "TEXT")
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "visibility", nullable = false, length = 20)
    @Builder.Default
    private PostVisibility visibility = PostVisibility.PUBLIC;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private PostStatus status = PostStatus.ACTIVE;

    @Column(name = "like_count", nullable = false)
    @Builder.Default
    private Integer likeCount = 0;

    @Column(name = "comment_count", nullable = false)
    @Builder.Default
    private Integer commentCount = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @Column(name = "moderated_at")
    private LocalDateTime moderatedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "moderated_by_id")
    private User moderatedBy;

    @Column(name = "moderation_reason", length = 255)
    private String moderationReason;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        if (updatedAt == null) updatedAt = now;
        if (likeCount == null) likeCount = 0;
        if (commentCount == null) commentCount = 0;
        if (visibility == null) visibility = PostVisibility.PUBLIC;
        if (status == null) status = PostStatus.ACTIVE;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

