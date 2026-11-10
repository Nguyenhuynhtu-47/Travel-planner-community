package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_blocks", uniqueConstraints = @UniqueConstraint(name = "uk_user_blocks_pair", columnNames = {"blocker_user_id", "blocked_user_id"}), indexes = {
    @Index(name = "idx_user_blocks_blocked_blocker", columnList = "blocked_user_id,blocker_user_id")
})
@Getter @Setter @NoArgsConstructor
public class UserBlock {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "block_id")
    private Long blockId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "blocker_user_id", nullable = false)
    private User blocker;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "blocked_user_id", nullable = false)
    private User blockedUser;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() { createdAt = LocalDateTime.now(); }
}
