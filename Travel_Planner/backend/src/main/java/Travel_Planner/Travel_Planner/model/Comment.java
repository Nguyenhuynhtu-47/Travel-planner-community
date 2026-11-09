package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "comments", indexes = {
        @Index(name = "idx_comments_itinerary_root_page",
                columnList = "itinerary_id, parent_comment_id, status, created_at, comment_id"),
        @Index(name = "idx_comments_activity_root_page",
                columnList = "activity_id, parent_comment_id, status, created_at, comment_id"),
        @Index(name = "idx_comments_thread_page",
                columnList = "root_comment_id, status, created_at, comment_id")
})
@Getter
@Setter
@Builder
public class Comment {

    public Comment() {
    }

    public Comment(Integer commentId, User user, Itinerary itinerary, String content, CommentStatus status,
                   LocalDateTime createdAt, LocalDateTime updatedAt) {
        this(commentId, user, itinerary, null, null, null, content, status, createdAt, updatedAt);
    }

    public Comment(Integer commentId, User user, Itinerary itinerary, Activity activity, Comment parentComment,
                   Comment rootComment, String content, CommentStatus status, LocalDateTime createdAt,
                   LocalDateTime updatedAt) {
        this.commentId = commentId;
        this.user = user;
        this.itinerary = itinerary;
        this.activity = activity;
        this.parentComment = parentComment;
        this.rootComment = rootComment;
        this.content = content;
        this.status = status;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "comment_id")
    private Integer commentId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "itinerary_id")
    private Itinerary itinerary;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "activity_id")
    private Activity activity;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_comment_id")
    private Comment parentComment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "root_comment_id")
    private Comment rootComment;

    @Column(name = "content", columnDefinition = "TEXT", nullable = false)
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private CommentStatus status = CommentStatus.ACTIVE;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.status == null) {
            this.status = CommentStatus.ACTIVE;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
