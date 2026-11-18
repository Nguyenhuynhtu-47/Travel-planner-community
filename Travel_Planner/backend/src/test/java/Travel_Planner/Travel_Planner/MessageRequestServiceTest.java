package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.response.ConversationSummaryResponse;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.model.Conversation;
import Travel_Planner.Travel_Planner.model.ConversationReadState;
import Travel_Planner.Travel_Planner.model.Message;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.ConversationReadStateRepository;
import Travel_Planner.Travel_Planner.repository.ConversationRepository;
import Travel_Planner.Travel_Planner.repository.MessageRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.ChatRateLimiter;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import Travel_Planner.Travel_Planner.service.impl.MessagingServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MessageRequestServiceTest {
    @Mock UserRepository users;
    @Mock ConversationRepository conversations;
    @Mock MessageRepository messages;
    @Mock ConversationReadStateRepository readStates;
    @Mock FriendshipService friendships;
    @Mock ChatRateLimiter rateLimiter;
    @Mock ApplicationEventPublisher events;

    private MessagingServiceImpl service;
    private User sender;
    private User recipient;

    @BeforeEach
    void setUp() {
        service = new MessagingServiceImpl(users, conversations, messages, readStates,
                friendships, rateLimiter, events, 4000);
        sender = User.builder().userId(1).username("sender").handle("sender").status(UserStatus.ACTIVE).build();
        recipient = User.builder().userId(2).username("recipient").handle("recipient").status(UserStatus.ACTIVE).build();
    }

    @Test
    void openingDirectWithStrangerCreatesPendingThreadWhereSenderCanContinue() {
        when(users.findByUsername("sender")).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(conversations.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.empty());
        when(friendships.canContinueConversation(1, 2)).thenReturn(true);
        when(friendships.areAcceptedFriends(1, 2)).thenReturn(false);
        when(conversations.saveAndFlush(any(Conversation.class))).thenAnswer(invocation -> {
            Conversation conversation = invocation.getArgument(0);
            conversation.setConversationId(42L);
            return conversation;
        });

        ConversationSummaryResponse response = service.openDirect(2, "sender");

        assertEquals(ConversationStatus.PENDING, response.getStatus());
        assertTrue(response.isCanSendMessage());
        assertFalse(response.isCanRespondToMessageRequest());
        verify(conversations).saveAndFlush(argThat(conversation ->
                conversation.getRequester().equals(sender)
                        && conversation.getRequestRecipient().equals(recipient)));
    }

    @Test
    void legacyConversationRemainsAcceptedAndCanContinueAfterPrivacyChange() {
        Conversation legacy = new Conversation();
        legacy.setConversationId(7L);
        legacy.setUserLow(sender);
        legacy.setUserHigh(recipient);
        when(users.findByUsername("sender")).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(conversations.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(legacy));
        when(friendships.canContinueConversation(1, 2)).thenReturn(true);

        ConversationSummaryResponse response = service.openDirect(2, "sender");

        assertEquals(ConversationStatus.ACCEPTED, response.getStatus());
        assertTrue(response.isCanSendMessage());
        verify(friendships, never()).canMessage(1, 2);
    }

    @Test
    void pendingRecipientCannotReplyToAHiddenFriendsOnlyRequest() {
        Conversation pending = new Conversation();
        pending.setConversationId(19L);
        pending.setUserLow(sender);
        pending.setUserHigh(recipient);
        pending.setStatus(ConversationStatus.PENDING);
        pending.setRequester(sender);
        pending.setRequestRecipient(recipient);
        when(conversations.findById(19L)).thenReturn(Optional.of(pending));
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(messages.findBySender_UserIdAndClientMessageId(eq(2), any())).thenReturn(Optional.empty());
        when(conversations.findByIdForUpdate(19L)).thenReturn(Optional.of(pending));

        SendMessageRequest request = new SendMessageRequest();
        request.setClientMessageId("a8e731db-5a09-4809-9210-34ef60a695ba");
        request.setContent("Trả lời khi chưa chấp nhận");

        assertThrows(ForbiddenException.class, () -> service.send(19L, request, "recipient"));
        verify(messages, never()).saveAndFlush(any());
        verify(events, never()).publishEvent(any(Object.class));
    }

    @Test
    void openingPendingRequestDoesNotAdvanceReadCursorAndMarkReadIsRejected() {
        Conversation pending = new Conversation();
        pending.setConversationId(27L);
        pending.setUserLow(sender);
        pending.setUserHigh(recipient);
        pending.setStatus(ConversationStatus.PENDING);
        pending.setRequester(sender);
        pending.setRequestRecipient(recipient);
        pending.setLastMessageSequence(2L);
        when(conversations.findByIdForUpdate(27L)).thenReturn(Optional.of(pending));
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(friendships.canContinueConversation(2, 1)).thenReturn(true);

        assertThrows(ForbiddenException.class, () -> service.markRead(27L, 2L, "recipient"));

        verify(readStates, never()).save(any());
        verify(events, never()).publishEvent(any(Object.class));
    }

    @Test
    void acceptingRequestAtomicallyAdvancesRecipientReadCursorToPendingMessage() {
        Conversation pending = new Conversation();
        pending.setConversationId(28L);
        pending.setUserLow(sender);
        pending.setUserHigh(recipient);
        pending.setStatus(ConversationStatus.PENDING);
        pending.setRequester(sender);
        pending.setRequestRecipient(recipient);
        pending.setLastMessageSequence(4L);
        when(conversations.findById(28L)).thenReturn(Optional.of(pending));
        when(conversations.findByIdForUpdate(28L)).thenReturn(Optional.of(pending));
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(friendships.canContinueConversation(2, 1)).thenReturn(true);
        when(friendships.canMessage(1, 2)).thenReturn(true);
        when(messages.countVisibleMessages(28L, 2)).thenReturn(4L);
        when(messages.findLastVisibleRequestSequence(28L, 1)).thenReturn(4L);
        when(readStates.findForUpdate(28L, 2)).thenReturn(Optional.empty());
        when(readStates.saveAndFlush(any(ConversationReadState.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ConversationSummaryResponse accepted = service.acceptMessageRequest(28L, "recipient");

        assertEquals(ConversationStatus.ACCEPTED, pending.getStatus());
        assertEquals(ConversationStatus.ACCEPTED, accepted.getStatus());
        verify(readStates).saveAndFlush(argThat((ConversationReadState state) ->
                state.getUser().equals(recipient) && state.getLastReadSequence().equals(4L)));
        verify(events, times(2)).publishEvent(any(Travel_Planner.Travel_Planner.service.CommittedChatEvent.class));
    }

    @Test
    void pendingRequesterCanSendUnlimitedSenderOnlyMessagesWhenFriendsOnly() {
        Conversation pending = new Conversation();
        pending.setConversationId(21L);
        pending.setUserLow(sender);
        pending.setUserHigh(recipient);
        pending.setStatus(ConversationStatus.PENDING);
        pending.setRequester(sender);
        pending.setRequestRecipient(recipient);
        pending.setRequestCreatedAt(LocalDateTime.now().minusMinutes(1));
        pending.setLastMessageAt(LocalDateTime.now());
        pending.setLastMessageSequence(1L);
        when(conversations.findById(21L)).thenReturn(Optional.of(pending));
        when(users.findByUsername("sender")).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(messages.findBySender_UserIdAndClientMessageId(eq(1), any())).thenReturn(Optional.empty());
        when(conversations.findByIdForUpdate(21L)).thenReturn(Optional.of(pending));
        when(friendships.canContinueConversation(1, 2)).thenReturn(true);
        when(friendships.canMessage(1, 2)).thenReturn(false);
        when(rateLimiter.allow(1)).thenReturn(true);
        when(messages.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));

        SendMessageRequest request = new SendMessageRequest();
        request.setClientMessageId("f0a8f153-80ac-4d39-a71a-b39dad1b8f5b");
        request.setContent("Tin nhắn thứ hai trước khi được chấp nhận");

        service.send(21L, request, "sender");
        verify(messages).saveAndFlush(argThat(message -> Boolean.FALSE.equals(message.getRecipientVisible())));
        verify(events).publishEvent(argThat((Object event) -> event instanceof Travel_Planner.Travel_Planner.service.CommittedChatEvent committed
                && !committed.deliverToSecondUser()));
    }

    @Test
    void recipientCannotSendUntilExplicitlyAcceptingVisibleEveryoneRequest() {
        Conversation pending = new Conversation();
        pending.setConversationId(22L);
        pending.setUserLow(sender);
        pending.setUserHigh(recipient);
        pending.setStatus(ConversationStatus.PENDING);
        pending.setRequester(sender);
        pending.setRequestRecipient(recipient);
        pending.setLastMessageSequence(2L);
        when(conversations.findById(22L)).thenReturn(Optional.of(pending));
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(messages.findBySender_UserIdAndClientMessageId(eq(2), any())).thenReturn(Optional.empty());
        when(conversations.findByIdForUpdate(22L)).thenReturn(Optional.of(pending));

        SendMessageRequest request = new SendMessageRequest();
        request.setClientMessageId("b8e731db-5a09-4809-9210-34ef60a695ba");
        request.setContent("Trả lời và chuyển vào hộp thư chính");

        assertThrows(ForbiddenException.class, () -> service.send(22L, request, "recipient"));

        assertEquals(ConversationStatus.PENDING, pending.getStatus());
        verify(messages, never()).saveAndFlush(any());
        verify(events, never()).publishEvent(any(Travel_Planner.Travel_Planner.service.CommittedChatEvent.class));
    }

    @Test
    void declineHidesPendingRequesterMessagesFromRecipientWithoutDeletingHistory() {
        Conversation pending = new Conversation();
        pending.setConversationId(29L);
        pending.setUserLow(sender);
        pending.setUserHigh(recipient);
        pending.setStatus(ConversationStatus.PENDING);
        pending.setRequester(sender);
        pending.setRequestRecipient(recipient);
        pending.setLastMessageSequence(1L);
        when(conversations.findById(29L)).thenReturn(Optional.of(pending));
        when(conversations.findByIdForUpdate(29L)).thenReturn(Optional.of(pending));
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(friendships.canMessage(1, 2)).thenReturn(true);
        when(messages.countVisibleMessages(29L, 2)).thenReturn(1L);

        ConversationSummaryResponse declined = service.declineMessageRequest(29L, "recipient");

        assertEquals(ConversationStatus.DECLINED, pending.getStatus());
        assertEquals(ConversationStatus.DECLINED, declined.getStatus());
        verify(messages).hideRequestMessagesFromRecipient(29L, 1);
    }

    @Test
    void acceptedConversationRemainsAcceptedAndVisibleAfterUnfriendRegardlessOfPrivacy() {
        Conversation accepted = new Conversation();
        accepted.setConversationId(23L);
        accepted.setUserLow(sender);
        accepted.setUserHigh(recipient);
        accepted.setStatus(ConversationStatus.ACCEPTED);
        accepted.setLastMessageSequence(4L);
        when(conversations.findById(23L)).thenReturn(Optional.of(accepted));
        when(users.findByUsername("sender")).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(messages.findBySender_UserIdAndClientMessageId(eq(1), any())).thenReturn(Optional.empty());
        when(conversations.findByIdForUpdate(23L)).thenReturn(Optional.of(accepted));
        when(friendships.canContinueConversation(1, 2)).thenReturn(true);
        when(rateLimiter.allow(1)).thenReturn(true);
        when(messages.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));

        SendMessageRequest request = new SendMessageRequest();
        request.setClientMessageId(UUID.randomUUID().toString());
        request.setContent("Tin nhắn sau khi hủy kết bạn");

        service.send(23L, request, "sender");

        assertEquals(ConversationStatus.ACCEPTED, accepted.getStatus());
        assertNull(accepted.getRequester());
        assertNull(accepted.getRequestRecipient());
        verify(messages).saveAndFlush(argThat(message -> Boolean.TRUE.equals(message.getRecipientVisible())));
        verify(friendships, never()).canMessage(1, 2);
        verify(conversations, never()).saveAndFlush(any());
    }

    @Test
    void restrictedPendingThreadKeepsOldVisibleHistoryButOnlyVisibleRowsAreReturned() {
        Conversation conversation = new Conversation();
        conversation.setConversationId(26L);
        conversation.setUserLow(sender);
        conversation.setUserHigh(recipient);
        conversation.setStatus(ConversationStatus.PENDING);
        conversation.setRequester(sender);
        conversation.setRequestRecipient(recipient);
        conversation.setLastMessageSequence(5L);
        Message oldMessage = new Message();
        oldMessage.setMessageId(100L);
        oldMessage.setConversation(conversation);
        oldMessage.setSequenceNumber(2L);
        oldMessage.setSender(sender);
        oldMessage.setClientMessageId("old-visible");
        oldMessage.setContent("Lịch sử trước khi hủy kết bạn");
        oldMessage.setCreatedAt(LocalDateTime.now().minusDays(1));
        oldMessage.setRecipientVisible(true);
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(friendships.canContinueConversation(2, 1)).thenReturn(true);
        when(conversations.findById(26L)).thenReturn(Optional.of(conversation));
        when(friendships.canMessage(1, 2)).thenReturn(false);
        when(messages.countVisibleMessages(26L, 2)).thenReturn(2L);
        when(readStates.findByConversation_ConversationIdAndUser_UserId(26L, 1))
                .thenReturn(Optional.empty());
        when(messages.findVisibleLatest(eq(26L), eq(2), any()))
                .thenReturn(java.util.List.of(oldMessage));

        var page = service.messages(26L, null, null, 30, "recipient");

        assertEquals(1, page.getContent().size());
        assertEquals("Lịch sử trước khi hủy kết bạn", page.getContent().getFirst().getContent());
    }

    @Test
    void declinedRequestBecomesRetryableAfterOneDay() {
        Conversation declined = new Conversation();
        declined.setConversationId(20L);
        declined.setUserLow(sender);
        declined.setUserHigh(recipient);
        declined.setStatus(ConversationStatus.DECLINED);
        declined.setRequester(sender);
        declined.setRequestRecipient(recipient);
        declined.setRequestDeclinedAt(LocalDateTime.now().minusDays(1).minusSeconds(1));
        when(users.findByUsername("sender")).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(conversations.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(declined));
        when(friendships.canContinueConversation(1, 2)).thenReturn(true);
        when(friendships.areAcceptedFriends(1, 2)).thenReturn(false);

        ConversationSummaryResponse response = service.openDirect(2, "sender");

        assertEquals(ConversationStatus.PENDING, response.getStatus());
        assertTrue(response.isCanSendMessage());
        assertNull(response.getRequestAvailableAt());
    }
}
