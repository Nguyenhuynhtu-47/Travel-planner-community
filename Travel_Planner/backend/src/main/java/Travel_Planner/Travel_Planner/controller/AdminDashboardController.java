package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.AdminDashboardAnalyticsResponse;
import Travel_Planner.Travel_Planner.dto.response.AdminDashboardSummaryResponse;
import Travel_Planner.Travel_Planner.service.AdminDashboardService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/admin/dashboard")
public class AdminDashboardController {

    private final AdminDashboardService adminDashboardService;

    public AdminDashboardController(AdminDashboardService adminDashboardService) {
        this.adminDashboardService = adminDashboardService;
    }

    @GetMapping("/summary")
    public ResponseEntity<AdminDashboardSummaryResponse> getSummary() {
        return ResponseEntity.ok(adminDashboardService.getSummary());
    }

    @GetMapping("/analytics")
    public ResponseEntity<AdminDashboardAnalyticsResponse> getAnalytics(
            @RequestParam(defaultValue = "30") int days) {
        return ResponseEntity.ok(adminDashboardService.getAnalytics(days));
    }
}
