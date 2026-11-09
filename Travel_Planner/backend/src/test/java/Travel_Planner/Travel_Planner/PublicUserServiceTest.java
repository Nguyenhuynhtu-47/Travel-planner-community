package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.PublicProfileResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.Follow;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.impl.PublicUserServiceImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PublicUserServiceTest {
    @Test
    void publicProfileDoesNotSerializePrivateAccountFields() throws Exception {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        User target = User.builder().userId(7).username("traveler").fullName("Traveler")
                .email("private@example.com").phone("123").address("Private address")
                .role(Role.ADMIN).status(UserStatus.ACTIVE).build();
        when(users.findById(7)).thenReturn(Optional.of(target));
        when(follows.countByFollowing_UserId(7)).thenReturn(4L);
        when(follows.countByFollower_UserId(7)).thenReturn(2L);
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class));

        PublicProfileResponse response = service.getProfile(7, null);
        String json = new ObjectMapper().writeValueAsString(response);
        assertTrue(json.contains("\"isFollowing\":false"));
        assertTrue(json.contains("\"followerCount\":4"));
        assertFalse(json.contains("private@example.com"));
        assertFalse(json.contains("123"));
        assertFalse(json.contains("Private address"));
        assertFalse(json.contains("ADMIN"));
    }

    @Test
    void userCannotFollowThemself() {
        UserRepository users = mock(UserRepository.class);
        User actor = User.builder().userId(3).username("same").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("same")).thenReturn(Optional.of(actor));
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, mock(FollowRepository.class),
                mock(ItineraryRepository.class), mock(RatingRepository.class));
        assertThrows(BadRequestException.class, () -> service.follow(3, "same"));
        verify(users, never()).findByUserIdForUpdate(any());
    }

    @Test
    void repeatedFollowDoesNotCreateDuplicateRelation() {
        UserRepository users = mock(UserRepository.class);
        FollowRepository follows = mock(FollowRepository.class);
        User actor = User.builder().userId(3).username("actor").status(UserStatus.ACTIVE).build();
        User target = User.builder().userId(7).username("target").status(UserStatus.ACTIVE).build();
        when(users.findByUsername("actor")).thenReturn(Optional.of(actor));
        when(users.findByUserIdForUpdate(7)).thenReturn(Optional.of(target));
        when(follows.existsByFollower_UserIdAndFollowing_UserId(3, 7)).thenReturn(true);
        PublicUserServiceImpl service = new PublicUserServiceImpl(users, follows,
                mock(ItineraryRepository.class), mock(RatingRepository.class));

        service.follow(7, "actor");

        verify(follows, never()).save(any(Follow.class));
    }
}
