package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.Friendship;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserMessagingSettings;
import Travel_Planner.Travel_Planner.model.enums.FriendshipStatus;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.FriendshipRepository;
import Travel_Planner.Travel_Planner.repository.UserBlockRepository;
import Travel_Planner.Travel_Planner.repository.UserMessagingSettingsRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.impl.FriendshipServiceImpl;
import Travel_Planner.Travel_Planner.service.SocialNotificationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.springframework.context.ApplicationEventPublisher;
import org.mockito.junit.jupiter.MockitoExtension;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FriendshipPrivacyServiceTest {
    @Mock UserRepository users;
    @Mock FriendshipRepository friendships;
    @Mock UserBlockRepository blocks;
    @Mock UserMessagingSettingsRepository settings;
    @Mock ApplicationEventPublisher events;
    @Mock SocialNotificationService socialNotifications;
    FriendshipServiceImpl service;
    User sender;
    User recipient;

    @BeforeEach
    void setUp() {
        service = new FriendshipServiceImpl(users, friendships, blocks, settings, events, socialNotifications);
        sender = User.builder().userId(1).username("sender").status(UserStatus.ACTIVE).build();
        recipient = User.builder().userId(2).username("recipient").status(UserStatus.ACTIVE).build();
    }

    @Test
    void defaultsToEveryoneAndAllowsStrangers() {
        when(users.findById(2)).thenReturn(Optional.of(recipient));
        when(blocks.existsBetween(1, 2)).thenReturn(false);
        when(settings.findById(2)).thenReturn(Optional.empty());
        assertTrue(service.canMessage(1, 2));

        UserMessagingSettings explicitFriendsOnly = new UserMessagingSettings();
        explicitFriendsOnly.setInboundPolicy(InboundMessagePolicy.FRIENDS_ONLY);
        when(settings.findById(2)).thenReturn(Optional.of(explicitFriendsOnly));
        when(friendships.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.empty());
        assertFalse(service.canMessage(1, 2));

        Friendship accepted = new Friendship();
        accepted.setStatus(FriendshipStatus.ACCEPTED);
        when(friendships.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(accepted));
        assertTrue(service.canMessage(1, 2));
    }

    @Test
    void everyoneAllowsStrangersAndBlockDeniesMessages() {
        when(users.findById(2)).thenReturn(Optional.of(recipient));
        when(blocks.existsBetween(1, 2)).thenReturn(false);
        UserMessagingSettings policy = new UserMessagingSettings();
        policy.setInboundPolicy(InboundMessagePolicy.EVERYONE);
        when(settings.findById(2)).thenReturn(Optional.of(policy));
        assertTrue(service.canMessage(1, 2));

        policy.setInboundPolicy(InboundMessagePolicy.EVERYONE);
        when(blocks.existsBetween(1, 2)).thenReturn(true);
        assertFalse(service.canMessage(1, 2));
    }

    @Test
    void legacyNobodyValueUsesFriendsOnlySemantics() {
        when(blocks.existsBetween(1, 2)).thenReturn(false);
        UserMessagingSettings policy = new UserMessagingSettings();
        policy.setInboundPolicy(InboundMessagePolicy.NOBODY);
        when(settings.findById(2)).thenReturn(Optional.of(policy));
        when(users.findById(1)).thenReturn(Optional.of(sender));
        when(users.findById(2)).thenReturn(Optional.of(recipient));
        assertFalse(service.canMessage(1, 2));
        assertTrue(service.canContinueConversation(1, 2));

        Friendship accepted = new Friendship();
        accepted.setStatus(FriendshipStatus.ACCEPTED);
        when(friendships.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(accepted));
        assertTrue(service.canMessage(1, 2));

        when(blocks.existsBetween(1, 2)).thenReturn(true);
        assertFalse(service.canContinueConversation(1, 2));
    }

    @Test
    void onlyNewFriendshipTransitionPublishesFriendRequestNotification() {
        when(users.findByUsername("sender")).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(blocks.existsBetween(1, 2)).thenReturn(false);
        when(friendships.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.empty());
        when(friendships.save(any(Friendship.class))).thenAnswer(invocation -> {
            Friendship relation = invocation.getArgument(0);
            relation.setFriendshipId(55L);
            return relation;
        });

        service.sendRequest(2, "sender");

        verify(socialNotifications).friendRequest(eq(sender), eq(recipient), argThat(relation ->
                relation.getStatus() == FriendshipStatus.PENDING && relation.getFriendshipId().equals(55L)));
    }

    @Test
    void acceptTransitionNotifiesOnlyTheOriginalRequester() {
        Friendship relation = new Friendship();
        relation.setFriendshipId(56L);
        relation.setUserLow(sender);
        relation.setUserHigh(recipient);
        relation.setRequestedByUser(sender);
        relation.setStatus(FriendshipStatus.PENDING);
        when(friendships.findById(56L)).thenReturn(Optional.of(relation));
        when(users.findByUsername("recipient")).thenReturn(Optional.of(recipient));
        when(users.findByUserIdForUpdate(1)).thenReturn(Optional.of(sender));
        when(users.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient));
        when(friendships.findByIdForUpdate(56L)).thenReturn(Optional.of(relation));
        when(blocks.existsBetween(1, 2)).thenReturn(false);

        service.accept(56L, "recipient");

        assertEquals(FriendshipStatus.ACCEPTED, relation.getStatus());
        verify(socialNotifications).friendRequestAccepted(recipient, sender, relation);
    }
}
