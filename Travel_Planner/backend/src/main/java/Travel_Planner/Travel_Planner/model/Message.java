package Travel_Planner.Travel_Planner.model;

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
    @Index(name = "idx_messages_sender_created", columnList = "sender_user_id,created_at")
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

    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }
}
