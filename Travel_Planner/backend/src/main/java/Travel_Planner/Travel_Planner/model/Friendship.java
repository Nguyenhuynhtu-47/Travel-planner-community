package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.FriendshipStatus;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "friendships", uniqueConstraints = @UniqueConstraint(name = "uk_friendships_user_pair", columnNames = {"user_low_id", "user_high_id"}), indexes = {
    @Index(name = "idx_friendship_low_status", columnList = "user_low_id,status,updated_at"),
    @Index(name = "idx_friendship_high_status", columnList = "user_high_id,status,updated_at"),
    @Index(name = "idx_friendship_requester_status", columnList = "requested_by_user_id,status,updated_at")
})
@Getter @Setter @NoArgsConstructor
public class Friendship {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "friendship_id")
    private Long friendshipId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_low_id", nullable = false)
    private User userLow;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_high_id", nullable = false)
    private User userHigh;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requested_by_user_id", nullable = false)
    private User requestedByUser;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 16)
    private FriendshipStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }

    public boolean includes(Integer id) {
        return id != null && (userLow.getUserId().equals(id) || userHigh.getUserId().equals(id));
    }

    public User otherUser(Integer id) {
        if (userLow.getUserId().equals(id)) return userHigh;
        if (userHigh.getUserId().equals(id)) return userLow;
        throw new IllegalArgumentException("User is not part of friendship");
    }
}
