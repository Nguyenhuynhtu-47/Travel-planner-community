package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.AdminDashboardAnalyticsResponse;
import Travel_Planner.Travel_Planner.dto.response.AdminDashboardSummaryResponse;

public interface AdminDashboardService {

    AdminDashboardSummaryResponse getSummary();

    AdminDashboardAnalyticsResponse getAnalytics(int days);
}
