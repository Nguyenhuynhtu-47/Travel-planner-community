package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;

@Entity
@Table(name = "conversations", uniqueConstraints = @UniqueConstraint(name = "uk_conversations_user_pair", columnNames = {"user_low_id", "user_high_id"}), indexes = {
    @Index(name = "idx_conversations_low_activity", columnList = "user_low_id,last_message_at,conversation_id"),
    @Index(name = "idx_conversations_high_activity", columnList = "user_high_id,last_message_at,conversation_id"),
    @Index(name = "idx_conversations_request_inbox", columnList = "request_recipient_user_id,conversation_status,updated_at")
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

    // Nullable for existing rows: a missing status is interpreted as an accepted legacy conversation.
    @Enumerated(EnumType.STRING)
    @Column(name = "conversation_status", length = 16)
    private ConversationStatus status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_user_id")
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "request_recipient_user_id")
    private User requestRecipient;

    @Column(name = "request_created_at")
    private LocalDateTime requestCreatedAt;

    @Column(name = "request_declined_at")
    private LocalDateTime requestDeclinedAt;

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

    public boolean isAccepted() {
        return status == null || status == ConversationStatus.ACCEPTED;
    }

    public User otherUser(Integer userId) {
        if (userLow.getUserId().equals(userId)) return userHigh;
        if (userHigh.getUserId().equals(userId)) return userLow;
        throw new IllegalArgumentException("User is not a conversation member");
    }
}
