package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Entity
@Table(name = "conversation_read_states", indexes = @Index(name = "idx_read_state_user_conversation", columnList = "user_id,conversation_id"))
@Getter @Setter @NoArgsConstructor
public class ConversationReadState {
    @EmbeddedId
    private ConversationReadStateId id;

    @MapsId("conversationId")
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @MapsId("userId")
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "last_read_sequence", nullable = false)
    private Long lastReadSequence = 0L;

    @Column(name = "last_read_at")
    private LocalDateTime lastReadAt;

    public ConversationReadState(Conversation conversation, User user) {
        this.conversation = conversation;
        this.user = user;
        this.id = new ConversationReadStateId(conversation.getConversationId(), user.getUserId());
        this.lastReadSequence = 0L;
    }
}
