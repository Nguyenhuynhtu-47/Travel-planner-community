package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.controller.NotificationController;
import Travel_Planner.Travel_Planner.dto.response.NotificationPageResponse;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.service.NotificationService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationControllerTest {
    @Mock private NotificationService notificationService;

    @Test
    void feedUsesAuthenticatedPrincipalAndBoundedPageInputs() {
        NotificationController controller = new NotificationController(notificationService);
        UserDetails principal = User.withUsername("alice").password("unused").roles("USER").build();
        NotificationPageResponse expected = NotificationPageResponse.builder()
                .content(List.of()).hasMore(false).build();
        when(notificationService.getFeed("alice", "cursor", 25, true, null)).thenReturn(expected);

        var response = controller.getFeed("cursor", 25, true, null, principal);

        assertSame(expected, response.getBody());
        verify(notificationService).getFeed("alice", "cursor", 25, true, null);
    }

    @Test
    void feedRejectsMissingPrincipal() {
        NotificationController controller = new NotificationController(notificationService);
        assertThrows(UnauthorizedException.class, () -> controller.getFeed(null, 20, false, null, null));
        verifyNoInteractions(notificationService);
    }
}
