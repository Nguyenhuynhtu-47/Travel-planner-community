package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.service.FcmMessageSender;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Component
@ConditionalOnProperty(name = "app.firebase.messaging.enabled", havingValue = "true")
public class FirebaseFcmMessageSender implements FcmMessageSender {
    private final FirebaseMessaging firebaseMessaging;

    public FirebaseFcmMessageSender(FirebaseApp app) {
        firebaseMessaging = FirebaseMessaging.getInstance(app);
    }

    @Override
    public void send(String token, String title, String body, String conversationId, String collapseKey) {
        Message message = Message.builder()
                .setFid(token)
                .setNotification(com.google.firebase.messaging.Notification.builder().setTitle(title).setBody(body).build())
                .putData("type", "MESSAGE_PUSH")
                .putData("conversationId", conversationId)
                .setAndroidConfig(AndroidConfig.builder()
                        .setCollapseKey(collapseKey)
                        .setTtl(Duration.ofHours(24).toMillis())
                        .build())
                .build();
        try {
            firebaseMessaging.send(message);
        } catch (FirebaseMessagingException exception) {
            throw new FcmSendException(exception);
        }
    }

    @Override
    public boolean isInvalidRegistration(RuntimeException exception) {
        return exception instanceof FcmSendException sendException
                && sendException.getCause() instanceof FirebaseMessagingException firebaseException
                && firebaseException.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED;
    }

    static final class FcmSendException extends RuntimeException {
        FcmSendException(FirebaseMessagingException cause) { super(cause); }
    }
}
