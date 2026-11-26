package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@ConditionalOnProperty(name = "app.firebase.messaging.enabled", havingValue = "true")
public class MessagingPushListener {
    private static final Logger logger = LoggerFactory.getLogger(MessagingPushListener.class);

    private final MessagingPushPolicy policy;
    private final FcmMessageSender sender;
    private final UserDeviceTokenRepository tokens;

    public MessagingPushListener(MessagingPushPolicy policy, FcmMessageSender sender,
            UserDeviceTokenRepository tokens) {
        this.policy = policy;
        this.sender = sender;
        this.tokens = tokens;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void sendAfterCommit(CommittedChatEvent event) {
        try {
            CommittedMessagePush push = policy.resolve(event);
            if (push == null) return;
            for (CommittedMessagePush.DevicePushToken token : push.tokens()) {
                try {
                    sender.send(token.token(), push.title(), push.body(), push.conversationId(), push.collapseKey());
                } catch (RuntimeException exception) {
                    if (sender.isInvalidRegistration(exception)) tokens.disable(token.id());
                    logger.warn("FCM message push failed for conversation {}", push.conversationId());
                }
            }
        } catch (RuntimeException exception) {
            logger.warn("FCM message push policy failed after commit for event {}", event.payload() == null
                    ? "unknown" : event.payload().getType());
        }
    }

}
