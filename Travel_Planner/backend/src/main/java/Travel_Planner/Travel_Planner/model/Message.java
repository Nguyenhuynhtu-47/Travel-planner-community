package Travel_Planner.Travel_Planner.model;

import Travel_Planner.Travel_Planner.model.enums.MessageType;
import Travel_Planner.Travel_Planner.model.enums.ShareTargetType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "messages", uniqueConstraints = {
    @UniqueConstraint(name = "uk_messages_conversation_sequence", columnNames = {"conversation_id", "sequence_number"}),
    @UniqueConstraint(name = "uk_messages_sender_client_id", columnNames = {"sender_user_id", "client_message_id"})
}, indexes = {
    @Index(name = "idx_messages_conversation_sequence", columnList = "conversation_id,sequence_number"),
    @Index(name = "idx_messages_sender_created", columnList = "sender_user_id,created_at"),
    @Index(name = "idx_messages_share_target", columnList = "share_target_type,share_target_id"),
    @Index(name = "idx_messages_share_batch", columnList = "share_batch_id,share_target_type,share_target_id")
})
@Getter @Setter @NoArgsConstructor
public class Message {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "message_id")
    private Long messageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @Column(name = "sequence_number", nullable = false)
    private Long sequenceNumber;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_user_id", nullable = false)
    private User sender;

    @Column(name = "client_message_id", nullable = false, length = 36)
    private String clientMessageId;

    @Column(name = "share_batch_id", length = 64)
    private String shareBatchId;

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "message_type", nullable = false, length = 16)
    private MessageType messageType = MessageType.TEXT;

    @Enumerated(EnumType.STRING)
    @Column(name = "share_target_type", length = 16)
    private ShareTargetType shareTargetType;

    @Column(name = "share_target_id")
    private Long shareTargetId;

    @Column(name = "share_metadata", columnDefinition = "TEXT")
    private String shareMetadata;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    // Null rows are legacy and remain visible; false means only the sender may read this message.
    @Column(name = "recipient_visible")
    private Boolean recipientVisible = true;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (messageType == null) messageType = MessageType.TEXT;
    }

    public boolean isShare() {
        return MessageType.SHARE.equals(messageType);
    }
}

