package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminDashboardSummaryResponse {

    private String healthStatus;
    private String serverTimestamp;

    // 1. Users
    private long totalUsers;
    private long activeUsers;
    private long bannedUsers;

    // 2. Places & Administrative Area coverage
    private long totalPlaces;
    private long activePlaces;
    private long linkedPlaces;
    private double placeAreaCoveragePercentage;

    // 3. Itineraries
    private long totalItineraries;
    private long publicItineraries;
    private long privateItineraries;
    private long activeItineraries;
    private long hiddenItineraries;

    // 4. Community Posts
    private long totalPosts;
    private long hiddenPosts;

    // 5. Violation Reports
    private long pendingReportsCount;

    // 6. Media Assets
    private long totalMediaAssets;
    private long deadLetterMediaAssets;
}
