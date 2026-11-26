package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.model.Conversation;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.ConversationRepository;
import Travel_Planner.Travel_Planner.repository.UserBlockRepository;
import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class MessagingPushPolicy {
    private final ConversationRepository conversations;
    private final UserRepository users;
    private final UserBlockRepository blocks;
    private final UserDeviceTokenRepository deviceTokens;
    private final FriendshipService friendships;

    public MessagingPushPolicy(ConversationRepository conversations, UserRepository users,
            UserBlockRepository blocks, UserDeviceTokenRepository deviceTokens, FriendshipService friendships) {
        this.conversations = conversations;
        this.users = users;
        this.blocks = blocks;
        this.deviceTokens = deviceTokens;
        this.friendships = friendships;
    }

    @Transactional(readOnly = true)
    public CommittedMessagePush resolve(CommittedChatEvent event) {
        if (!event.deliverToSecondUser() || event.payload() == null
                || !"MESSAGE_CREATED".equals(event.payload().getType())
                || event.payload().getConversationId() == null
                || event.payload().getMessage() == null
                || !Boolean.TRUE.equals(event.payload().getMessage().getRecipientVisible())
                || event.firstUserId() == null || event.secondUserId() == null
                || event.firstUserId().equals(event.secondUserId())) return null;

        Conversation conversation = conversations.findById(event.payload().getConversationId()).orElse(null);
        User sender = users.findById(event.firstUserId()).orElse(null);
        User recipient = users.findById(event.secondUserId()).orElse(null);
        if (conversation == null || sender == null || recipient == null
                || !conversation.includes(sender.getUserId()) || !conversation.includes(recipient.getUserId())
                || sender.getStatus() != UserStatus.ACTIVE || recipient.getStatus() != UserStatus.ACTIVE
                || blocks.existsBetween(sender.getUserId(), recipient.getUserId())) return null;

        boolean pendingRequest = conversation.getStatus() == ConversationStatus.PENDING;
        if (pendingRequest) {
            if (conversation.getRequester() == null || conversation.getRequestRecipient() == null
                    || !conversation.getRequester().getUserId().equals(sender.getUserId())
                    || !conversation.getRequestRecipient().getUserId().equals(recipient.getUserId())
                    || !friendships.canMessage(sender.getUserId(), recipient.getUserId())) return null;
        } else if (!conversation.isAccepted()) {
            return null;
        }

        List<CommittedMessagePush.DevicePushToken> activeTokens = deviceTokens
                .findAllByUser_UserIdAndDisabledAtIsNull(recipient.getUserId()).stream()
                .map(token -> new CommittedMessagePush.DevicePushToken(token.getDeviceTokenId(), token.getFcmToken()))
                .toList();
        if (activeTokens.isEmpty()) return null;

        String conversationId = conversation.getConversationId().toString();
        boolean newRequest = pendingRequest && event.newMessageRequest();
        String title = newRequest ? "Yêu cầu tin nhắn mới" : "Tin nhắn mới";
        String body = newRequest ? "Bạn có một yêu cầu tin nhắn mới." : "Bạn có tin nhắn mới.";
        String collapseKey = (pendingRequest ? "message-request-" : "message-") + conversationId;
        return new CommittedMessagePush(title, body, conversationId, collapseKey, activeTokens);
    }
}
