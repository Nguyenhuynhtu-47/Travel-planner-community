package Travel_Planner.Travel_Planner.seeder;

import lombok.Builder;
import lombok.Getter;
import lombok.ToString;

@Getter
@Builder
@ToString
public class SeedResult {
    private final long usersCount;
    private final long destinationsCount;
    private final long itinerariesCount;
    private final long daysCount;
    private final long activitiesCount;
    private final long commentsCount;
    private final long ratingsCount;
    private final long favoritesCount;
    private final long savedItinerariesCount;
    private final long followsCount;
    private final long sharesCount;
    private final long downloadsCount;
    private final boolean newlySeeded;
}
