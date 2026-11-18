package Travel_Planner.Travel_Planner.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import Travel_Planner.Travel_Planner.repository.UserBlockRepository;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ChatEventListener {
    private static final Logger logger = LoggerFactory.getLogger(ChatEventListener.class);
    private final SimpMessagingTemplate messaging;
    private final UserBlockRepository blocks;

    public ChatEventListener(SimpMessagingTemplate messaging, UserBlockRepository blocks) {
        this.messaging = messaging;
        this.blocks = blocks;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void publish(CommittedChatEvent event) {
        try {
            if ("CONVERSATION_ACCESS_REVOKED".equals(event.payload().getType())) {
                messaging.convertAndSendToUser(event.firstUsername(), "/queue/chat-events", event.payload());
                return;
            }
            if (event.firstUserId() != null && event.secondUserId() != null
                    && blocks.existsBetween(event.firstUserId(), event.secondUserId())) {
                return;
            }
            messaging.convertAndSendToUser(event.firstUsername(), "/queue/chat-events", event.payload());
            if (event.deliverToSecondUser() && !event.firstUsername().equals(event.secondUsername())) {
                messaging.convertAndSendToUser(event.secondUsername(), "/queue/chat-events", event.payload());
            }
        } catch (RuntimeException ex) {
            logger.warn("Chat event delivery failed after commit for conversation {}", event.payload().getConversationId());
        }
    }
}
