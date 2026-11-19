package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import Travel_Planner.Travel_Planner.service.impl.RatingServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

class RatingBlockAccessTest {
    @Test
    void blockedViewerCannotReadRatingSummaryDirectly() {
        RatingRepository ratings = mock(RatingRepository.class);
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        UserRepository users = mock(UserRepository.class);
        FriendshipService friendships = mock(FriendshipService.class);
        User owner = User.builder().userId(1).username("owner").status(UserStatus.ACTIVE).build();
        User viewer = User.builder().userId(2).username("viewer").status(UserStatus.ACTIVE).build();
        Itinerary itinerary = Itinerary.builder().itineraryId(10).user(owner)
                .status(ItineraryStatus.ACTIVE).visibility(Visibility.PUBLIC).build();
        when(itineraries.findById(10)).thenReturn(Optional.of(itinerary));
        when(users.findByUsername("viewer")).thenReturn(Optional.of(viewer));
        when(friendships.isBlockedBetween(2, 1)).thenReturn(true);
        RatingServiceImpl service = new RatingServiceImpl(ratings, itineraries, users,
                mock(PlatformTransactionManager.class), friendships);

        assertThrows(ResourceNotFoundException.class, () -> service.getRatingSummary(10, "viewer"));
        verify(ratings, never()).findAverageRatingByItineraryId(any());
    }
}
