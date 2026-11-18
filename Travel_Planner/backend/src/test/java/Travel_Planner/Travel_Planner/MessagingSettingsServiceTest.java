package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.MessagingSettingsResponse;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserMessagingSettings;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserMessagingSettingsRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.impl.MessagingSettingsServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MessagingSettingsServiceTest {
    @Mock UserRepository users;
    @Mock UserMessagingSettingsRepository settings;
    @InjectMocks MessagingSettingsServiceImpl service;

    @Test
    void updatePersistsTheSelectedPolicyForTheAuthenticatedUser() {
        User user = User.builder()
                .userId(42)
                .username("traveler")
                .status(UserStatus.ACTIVE)
                .build();
        when(users.findByUsername("traveler")).thenReturn(Optional.of(user));
        when(settings.findById(42)).thenReturn(Optional.empty());
        when(settings.save(any(UserMessagingSettings.class)))
                .thenAnswer(invocation -> {
                    UserMessagingSettings value = invocation.getArgument(0);
                    assertEquals(null, value.getUserId(), "new @MapsId row must be persisted, not merged");
                    value.setUserId(value.getUser().getUserId()); // @MapsId assigns the identifier on persist.
                    return value;
                });

        MessagingSettingsResponse response = service.update(
                InboundMessagePolicy.FRIENDS_ONLY, "traveler");

        ArgumentCaptor<UserMessagingSettings> saved = ArgumentCaptor.forClass(UserMessagingSettings.class);
        verify(settings).save(saved.capture());
        assertEquals(42, saved.getValue().getUserId());
        assertEquals(InboundMessagePolicy.FRIENDS_ONLY, saved.getValue().getInboundPolicy());
        assertEquals(InboundMessagePolicy.FRIENDS_ONLY, response.getInboundPolicy());
    }
}
