package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.ChatEventResponse;
import Travel_Planner.Travel_Planner.repository.UserBlockRepository;
import Travel_Planner.Travel_Planner.service.ChatEventListener;
import Travel_Planner.Travel_Planner.service.CommittedChatEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ChatEventListenerTest {
    @Mock SimpMessagingTemplate messaging;
    @Mock UserBlockRepository blocks;
    @InjectMocks ChatEventListener listener;

    @Test
    void suppressesRealtimeDeliveryWhenEitherUserBlockedTheOther() {
        ChatEventResponse payload = ChatEventResponse.builder()
                .eventId("event-1").type("MESSAGE_CREATED").build();
        CommittedChatEvent event = new CommittedChatEvent(
                "sender", 1, "recipient", 2, payload);
        when(blocks.existsBetween(1, 2)).thenReturn(true);

        listener.publish(event);

        verify(blocks).existsBetween(1, 2);
        verifyNoInteractions(messaging);
    }

    @Test
    void broadcastsToBothParticipantsWhenNoBlockExists() {
        ChatEventResponse payload = ChatEventResponse.builder()
                .eventId("event-2").type("MESSAGE_CREATED").build();
        CommittedChatEvent event = new CommittedChatEvent(
                "sender", 1, "recipient", 2, payload);
        when(blocks.existsBetween(1, 2)).thenReturn(false);

        listener.publish(event);

        verify(messaging).convertAndSendToUser("sender", "/queue/chat-events", payload);
        verify(messaging).convertAndSendToUser("recipient", "/queue/chat-events", payload);
    }
}
