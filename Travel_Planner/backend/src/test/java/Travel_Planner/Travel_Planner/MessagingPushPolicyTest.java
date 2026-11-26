package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.ChatEventResponse;
import Travel_Planner.Travel_Planner.dto.response.MessageResponse;
import Travel_Planner.Travel_Planner.model.Conversation;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserDeviceToken;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.ConversationRepository;
import Travel_Planner.Travel_Planner.repository.UserBlockRepository;
import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.CommittedChatEvent;
import Travel_Planner.Travel_Planner.service.CommittedMessagePush;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import Travel_Planner.Travel_Planner.service.MessagingPushPolicy;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MessagingPushPolicyTest {
    @Mock private ConversationRepository conversations;
    @Mock private UserRepository users;
    @Mock private UserBlockRepository blocks;
    @Mock private UserDeviceTokenRepository tokens;
    @Mock private FriendshipService friendships;

    private MessagingPushPolicy policy;
    private User sender;
    private User recipient;
    private Conversation conversation;
    private UserDeviceToken deviceToken;

    @BeforeEach
    void setUp() {
        policy = new MessagingPushPolicy(conversations, users, blocks, tokens, friendships);
        sender = User.builder().userId(10).username("sender").status(UserStatus.ACTIVE).build();
        recipient = User.builder().userId(20).username("recipient").status(UserStatus.ACTIVE).build();
        conversation = new Conversation();
        conversation.setConversationId(71L);
        conversation.setUserLow(sender);
        conversation.setUserHigh(recipient);
        conversation.setStatus(ConversationStatus.ACCEPTED);
        deviceToken = new UserDeviceToken();
        deviceToken.setDeviceTokenId(91L);
        deviceToken.setFcmToken("installation-id");
        when(conversations.findById(71L)).thenReturn(Optional.of(conversation));
        when(users.findById(10)).thenReturn(Optional.of(sender));
        when(users.findById(20)).thenReturn(Optional.of(recipient));
        when(blocks.existsBetween(10, 20)).thenReturn(false);
    }

    @Test
    void acceptedConversationProducesGenericPushAndCollapseKey() {
        when(tokens.findAllByUser_UserIdAndDisabledAtIsNull(20)).thenReturn(List.of(deviceToken));
        CommittedMessagePush result = policy.resolve(event(true, false));

        assertNotNull(result);
        assertEquals("Tin nhắn mới", result.title());
        assertEquals("Bạn có tin nhắn mới.", result.body());
        assertEquals("71", result.conversationId());
        assertEquals("message-71", result.collapseKey());
        assertEquals("installation-id", result.tokens().getFirst().token());
    }

    @Test
    void newVisiblePendingRequestProducesRequestCopyWithoutMessageContent() {
        conversation.setStatus(ConversationStatus.PENDING);
        conversation.setRequester(sender);
        conversation.setRequestRecipient(recipient);
        when(friendships.canMessage(10, 20)).thenReturn(true);
        when(tokens.findAllByUser_UserIdAndDisabledAtIsNull(20)).thenReturn(List.of(deviceToken));

        CommittedMessagePush result = policy.resolve(event(true, true));

        assertNotNull(result);
        assertEquals("Yêu cầu tin nhắn mới", result.title());
        assertFalse(result.body().contains("private message content"));
        assertEquals("message-request-71", result.collapseKey());
    }

    @Test
    void hiddenOrBlockedPendingMessageNeverProducesRecipientPush() {
        conversation.setStatus(ConversationStatus.PENDING);
        conversation.setRequester(sender);
        conversation.setRequestRecipient(recipient);
        when(friendships.canMessage(10, 20)).thenReturn(false);

        assertNull(policy.resolve(event(true, true)));
        assertNull(policy.resolve(event(false, true)));
    }

    private CommittedChatEvent event(boolean recipientVisible, boolean newRequest) {
        MessageResponse message = MessageResponse.builder().conversationId(71L).senderUserId(10)
                .recipientVisible(recipientVisible).content("private message content").build();
        ChatEventResponse payload = ChatEventResponse.builder().type("MESSAGE_CREATED")
                .conversationId(71L).message(message).build();
        return new CommittedChatEvent("sender", 10, "recipient", 20, payload, true, newRequest);
    }
}
