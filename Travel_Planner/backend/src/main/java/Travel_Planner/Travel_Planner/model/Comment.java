package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "comments")
@Getter
@Setter
@Builder
public class Comment {

    public Comment() {
    }

    public Comment(Integer commentId, User user, Itinerary itinerary, String content, CommentStatus status,
                   LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.commentId = commentId;
        this.user = user;
        this.itinerary = itinerary;
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
    @JoinColumn(name = "itinerary_id", nullable = false)
    private Itinerary itinerary;

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
