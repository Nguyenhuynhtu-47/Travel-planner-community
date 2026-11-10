package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "conversations", uniqueConstraints = @UniqueConstraint(name = "uk_conversations_user_pair", columnNames = {"user_low_id", "user_high_id"}), indexes = {
    @Index(name = "idx_conversations_low_activity", columnList = "user_low_id,last_message_at,conversation_id"),
    @Index(name = "idx_conversations_high_activity", columnList = "user_high_id,last_message_at,conversation_id")
})
@Getter @Setter @NoArgsConstructor
public class Conversation {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "conversation_id")
    private Long conversationId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_low_id", nullable = false)
    private User userLow;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_high_id", nullable = false)
    private User userHigh;

    @Column(name = "last_message_sequence", nullable = false)
    private Long lastMessageSequence = 0L;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_message_id", foreignKey = @ForeignKey(name = "fk_conversations_last_message"))
    private Message lastMessage;

    @Column(name = "last_message_at")
    private LocalDateTime lastMessageAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        createdAt = now;
        updatedAt = now;
        if (lastMessageSequence == null) lastMessageSequence = 0L;
    }

    @PreUpdate
    protected void onUpdate() { updatedAt = LocalDateTime.now(); }

    public boolean includes(Integer userId) {
        return userId != null && (userLow.getUserId().equals(userId) || userHigh.getUserId().equals(userId));
    }

    public User otherUser(Integer userId) {
        if (userLow.getUserId().equals(userId)) return userHigh;
        if (userHigh.getUserId().equals(userId)) return userLow;
        throw new IllegalArgumentException("User is not a conversation member");
    }
}
