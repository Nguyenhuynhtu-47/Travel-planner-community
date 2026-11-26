package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserDeviceToken;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.impl.DeviceTokenServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DeviceTokenServiceImplTest {
    @Mock private UserRepository users;
    @Mock private UserDeviceTokenRepository tokens;

    @Test
    void upsertBindsFidToAuthenticatedAccountAndStoresOnlyItsHashForUniqueness() {
        User user = User.builder().userId(7).username("traveler").status(UserStatus.ACTIVE).build();
        UserDeviceToken previous = new UserDeviceToken();
        previous.setDeviceTokenId(12L);
        when(users.findByUsernameForUpdate("traveler")).thenReturn(Optional.of(user));
        when(tokens.findByFcmTokenHash(anyString())).thenReturn(Optional.of(previous));

        DeviceTokenServiceImpl service = new DeviceTokenServiceImpl(users, tokens);
        service.upsert("traveler", "example-firebase-installation-id", "ANDROID");

        ArgumentCaptor<String> hash = ArgumentCaptor.forClass(String.class);
        verify(tokens).findByFcmTokenHash(hash.capture());
        assertEquals(64, hash.getValue().length());
        assertNotEquals("example-firebase-installation-id", hash.getValue());
        verify(tokens).save(previous);
        assertSame(user, previous.getUser());
        assertEquals("example-firebase-installation-id", previous.getFcmToken());
        assertEquals(hash.getValue(), previous.getFcmTokenHash());
        assertNull(previous.getDisabledAt());
    }

    @Test
    void unregisterDeletesOnlyTheCurrentAccountsMatchingInstallation() {
        User user = User.builder().userId(7).username("traveler").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("traveler")).thenReturn(Optional.of(user));
        DeviceTokenServiceImpl service = new DeviceTokenServiceImpl(users, tokens);

        service.unregister("traveler", "example-firebase-installation-id");

        verify(tokens).deleteOwnedToken(argThat(value -> value.length() == 64), eq(7));
    }
}
