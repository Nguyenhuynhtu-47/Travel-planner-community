package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "follows", uniqueConstraints = {
    @UniqueConstraint(name = "uk_follow_follower_following", columnNames = {"follower_id", "following_id"})
})
@Getter
@Setter
@Builder
public class Follow {

    public Follow() {
    }

    public Follow(Integer followId, User follower, User following, LocalDateTime createdAt) {
        this.followId = followId;
        this.follower = follower;
        this.following = following;
        this.createdAt = createdAt;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "follow_id")
    private Integer followId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "follower_id", nullable = false)
    private User follower;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "following_id", nullable = false)
    private User following;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
