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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
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
    FriendshipServiceImpl service;
    User sender;
    User recipient;

    @BeforeEach
    void setUp() {
        service = new FriendshipServiceImpl(users, friendships, blocks, settings);
        sender = User.builder().userId(1).username("sender").status(UserStatus.ACTIVE).build();
        recipient = User.builder().userId(2).username("recipient").status(UserStatus.ACTIVE).build();
        when(users.findById(2)).thenReturn(Optional.of(recipient));
    }

    @Test
    void defaultsToFriendsOnlyAndAllowsAcceptedFriends() {
        when(blocks.existsBetween(1, 2)).thenReturn(false);
        when(settings.findById(2)).thenReturn(Optional.empty());
        when(friendships.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.empty());
        assertFalse(service.canMessage(1, 2));

        Friendship accepted = new Friendship();
        accepted.setStatus(FriendshipStatus.ACCEPTED);
        when(friendships.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(accepted));
        assertTrue(service.canMessage(1, 2));
    }

    @Test
    void everyoneAllowsStrangersButNobodyAndBlockDenyMessages() {
        when(blocks.existsBetween(1, 2)).thenReturn(false);
        UserMessagingSettings policy = new UserMessagingSettings();
        policy.setInboundPolicy(InboundMessagePolicy.EVERYONE);
        when(settings.findById(2)).thenReturn(Optional.of(policy));
        assertTrue(service.canMessage(1, 2));

        policy.setInboundPolicy(InboundMessagePolicy.NOBODY);
        assertFalse(service.canMessage(1, 2));

        policy.setInboundPolicy(InboundMessagePolicy.EVERYONE);
        when(blocks.existsBetween(1, 2)).thenReturn(true);
        assertFalse(service.canMessage(1, 2));
    }
}