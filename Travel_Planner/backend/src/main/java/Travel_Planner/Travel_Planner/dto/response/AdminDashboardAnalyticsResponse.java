package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminDashboardAnalyticsResponse {

    private int days;
    private String fromDate;
    private String toDate;
    private List<TimeSeriesPoint> userRegistrationsDaily;
    private List<TimeSeriesPoint> communityPostsWeekly;
    private List<TopPlaceItem> topPlaces;
    private List<AuditLogResponse> recentAuditLogs;

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TimeSeriesPoint {
        private String label;
        private long count;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TopPlaceItem {
        private Long placeId;
        private String name;
        private String category;
        private String areaName;
        private long itineraryCount;
    }
}
