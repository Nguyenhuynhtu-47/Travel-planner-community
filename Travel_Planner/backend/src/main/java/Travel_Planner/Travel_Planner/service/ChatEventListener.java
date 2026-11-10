package Travel_Planner.Travel_Planner.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ChatEventListener {
    private static final Logger logger = LoggerFactory.getLogger(ChatEventListener.class);
    private final SimpMessagingTemplate messaging;

    public ChatEventListener(SimpMessagingTemplate messaging) { this.messaging = messaging; }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void publish(CommittedChatEvent event) {
        try {
            messaging.convertAndSendToUser(event.firstUsername(), "/queue/chat-events", event.payload());
            if (!event.firstUsername().equals(event.secondUsername())) {
                messaging.convertAndSendToUser(event.secondUsername(), "/queue/chat-events", event.payload());
            }
        } catch (RuntimeException ex) {
            logger.warn("Chat event delivery failed after commit for conversation {}", event.payload().getConversationId());
        }
    }
}
