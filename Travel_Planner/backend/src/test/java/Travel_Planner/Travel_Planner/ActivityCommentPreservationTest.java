package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.impl.ItineraryServiceImpl;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ActivityCommentPreservationTest {
    @Test
    void deletingActivityMovesItsCommentThreadToItineraryAndUpdatesCounter() {
        ItineraryRepository itineraries = mock(ItineraryRepository.class);
        RatingRepository ratings = mock(RatingRepository.class);
        ItineraryDayRepository days = mock(ItineraryDayRepository.class);
        ActivityRepository activities = mock(ActivityRepository.class);
        UserRepository users = mock(UserRepository.class);
        DestinationRepository destinations = mock(DestinationRepository.class);
        FavoriteRepository favorites = mock(FavoriteRepository.class);
        SavedItineraryRepository saved = mock(SavedItineraryRepository.class);
        CommentRepository comments = mock(CommentRepository.class);
        ItineraryServiceImpl service = new ItineraryServiceImpl(itineraries, ratings, days, activities, users,
                destinations, favorites, saved, comments);

        User owner = User.builder().userId(1).username("owner").build();
        Itinerary itinerary = Itinerary.builder().itineraryId(10).user(owner).status(ItineraryStatus.ACTIVE)
                .commentCount(2).build();
        ItineraryDay day = mock(ItineraryDay.class);
        Activity activity = mock(Activity.class);
        when(itineraries.findById(10)).thenReturn(Optional.of(itinerary));
        when(days.findByDayIdAndItinerary_ItineraryId(20, 10)).thenReturn(Optional.of(day));
        when(activities.findByActivityIdAndItineraryDay_DayId(7, 20)).thenReturn(Optional.of(activity));
        when(activity.getDisplayOrder()).thenReturn(1);
        when(comments.countByActivity_ActivityIdInAndStatus(List.of(7), CommentStatus.ACTIVE)).thenReturn(3L);
        when(activities.findByItineraryDay_DayIdOrderByDisplayOrderAsc(20)).thenReturn(List.of());
        when(itineraries.save(any(Itinerary.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.deleteActivity(10, 20, 7, "owner");

        verify(comments).moveActivityCommentsToItinerary(List.of(7), itinerary);
        verify(activities).delete(activity);
        assertEquals(5, itinerary.getCommentCount());
    }
}
