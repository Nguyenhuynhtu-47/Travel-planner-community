package Travel_Planner.Travel_Planner.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.io.Serializable;

@Embeddable
@Getter @Setter @NoArgsConstructor @EqualsAndHashCode
public class ConversationReadStateId implements Serializable {
    @Column(name = "conversation_id")
    private Long conversationId;
    @Column(name = "user_id")
    private Integer userId;

    public ConversationReadStateId(Long conversationId, Integer userId) {
        this.conversationId = conversationId;
        this.userId = userId;
    }
}
